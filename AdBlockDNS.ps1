<#
    .SYNOPSIS
    System Security & Telemetry Manager

    .DESCRIPTION
    A lightweight, GUI-based tool to manage system DNS settings and block telemetry.

    Features:
    - Smart Merge: Preserves user's existing custom entries in the hosts file.
    - Backup System: Automatically creates backups before modification.
    - Theme Engine: Auto-detects System Light/Dark mode (Apps & System).
    - Zero Dependencies: Runs purely on PowerShell + .NET (WPF).
    Fixes & Optimizations:
    - Pure .NET File I/O for zero UI freezing.
    - Lightweight Telemetry-only blocking to prevent Windows Dnscache crashes.
    - Applies settings to all physical network adapters (Ethernet & Wi-Fi) simultaneously.

    .AUTHOR
    @osmanonurkoc

    .LICENSE
    MIT License
#>

# =========================================================
# 1. ENVIRONMENT & PRIVILEGE CHECKS
# =========================================================
# The script requires Administrator privileges to modify network settings and the hosts file.
if ([IntPtr]::Size -eq 4 -and [Environment]::Is64BitOperatingSystem) {
    $RelaunchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $PowerShell64 = "$env:windir\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $PowerShell64) {
        Start-Process $PowerShell64 -ArgumentList $RelaunchArgs -Verb RunAs
        Exit
    }
}

# =========================================================
# 2. LOAD .NET ASSEMBLIES (WPF FRAMEWORK)
# =========================================================
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    exit
}

# =========================================================
# 3. NATIVE WIN32 API INTEGRATION
# =========================================================
# Helper for Window styling (Dark mode title bars) and Icon management
if (-not ("Win32" -as [type])) {
    $Win32Code = @'
        using System;
        using System.Runtime.InteropServices;
        public class Win32 {
            [DllImport("dwmapi.dll", PreserveSig = true)]
            public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern IntPtr SendMessage(IntPtr hWnd, UInt32 Msg, IntPtr wParam, IntPtr lParam);
        }
'@
    Add-Type -TypeDefinition $Win32Code -Language CSharp
}

# =========================================================
# 4. CONFIGURATION & GLOBAL RESOURCES
# =========================================================
$AppIconBase64 = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAE8GlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgOS4xLWMwMDMgNzkuOTY5MGE4NywgMjAyNS8wMy8wNi0xOToxMjowMyAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iIHhtbG5zOnBob3Rvc2hvcD0iaHR0cDovL25zLmFkb2JlLmNvbS9waG90b3Nob3AvMS4wLyIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0RXZ0PSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VFdmVudCMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIDI2LjExIChXaW5kb3dzKSIgeG1wOkNyZWF0ZURhdGU9IjIwMjYtMDEtMDlUMTQ6NDc6MzMrMDM6MDAiIHhtcDpNb2RpZnlEYXRlPSIyMDI2LTAxLTA5VDE0OjQ4OjQyKzAzOjAwIiB4bXA6TWV0YWRhdGFEYXRlPSIyMDI2LTAxLTA5VDE0OjQ4OjQyKzAzOjAwIiBkYzpmb3JtYXQ9ImltYWdlL3BuZyIgcGhvdG9zaG9wOkNvbG9yTW9kZT0iMyIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDowZGNmYmEzZi0wNjAyLTNkNDYtYjNmZC00ZjcyOGIyNTMxYjYiIHhtcE1NOkRvY3VtZW50SUQ9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"

$script:HostsPath = "$env:windir\System32\drivers\etc\hosts"
# Handle SysNative redirection for certain environments
if ([Environment]::Is64BitOperatingSystem -and [IntPtr]::Size -eq 4) {
    $SysNativePath = "$env:windir\Sysnative\drivers\etc\hosts"
    if (Test-Path $SysNativePath) { $script:HostsPath = $SysNativePath }
}

$script:HostsBackupPath = "$($script:HostsPath).bak"
$script:BlockStartTag = "# [TelemetryBlocker-Start] - DO NOT EDIT THIS BLOCK"
$script:BlockEndTag   = "# [TelemetryBlocker-End]"

# DNS Providers (OrderedDictionary)
$script:DNSProviders = [ordered]@{
    "Default (DHCP)"   = "DHCP"
    "Google DNS"       = "8.8.8.8,8.8.4.4"
    "Cloudflare"       = "1.1.1.1,1.0.0.1"
    "AdGuard Default"  = "94.140.14.14,94.140.15.15"
    "OpenDNS Home"     = "208.67.222.222,208.67.220.220"
    "Quad9"            = "9.9.9.9,149.112.112.112"
    "Control-D"        = "76.76.2.2,76.76.10.2"
}

# Focused only on Telemetry/Spyware to keep the list lightweight for Windows Dnscache
$script:AdBlockSources = @(
    "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
)

# =========================================================
# 5. THEME ENGINE
# =========================================================
# Detects if Windows is in Light or Dark mode.
function Get-SystemTheme {
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    try {
        $themeData = Get-ItemProperty -Path $regKey -ErrorAction Stop

        # Priority 1: Check AppsUseLightTheme
        if ($themeData.PSObject.Properties.Match("AppsUseLightTheme").Count -gt 0) {
            if ($themeData.AppsUseLightTheme -eq 1) { return "Light" }
            return "Dark"
        }
        # Priority 2: Fallback to SystemUsesLightTheme
        if ($themeData.PSObject.Properties.Match("SystemUsesLightTheme").Count -gt 0) {
            if ($themeData.SystemUsesLightTheme -eq 1) { return "Light" }
            return "Dark"
        }
        return "Dark"
    } catch { return "Dark" }
}

$CurrentTheme = Get-SystemTheme
$Themes = @{
    "Dark" = @{
        "Bg" = "#202020"; "Surface" = "#2D2D30"; "Text" = "#FFFFFF"; "SubText" = "#AAAAAA";
        "Border" = "#454545"; "Accent" = "#0078D4"; "ToggleOff" = "#333333"; "ToggleThumb" = "#FFFFFF";
        "Green" = "#32D74B"; "Red" = "#FF453A"; "InputBg" = "#333333"; "Orange" = "#FFA500"
    }
    "Light" = @{
        "Bg" = "#F3F3F3"; "Surface" = "#FFFFFF"; "Text" = "#000000"; "SubText" = "#666666";
        "Border" = "#E5E5E5"; "Accent" = "#0078D4"; "ToggleOff" = "#E0E0E0"; "ToggleThumb" = "#FFFFFF";
        "Green" = "#107C10"; "Red" = "#E81123"; "InputBg" = "#FFFFFF"; "Orange" = "#FF8C00"
    }
}

# Fix for dictionary key check
if (-not $Themes.Contains($CurrentTheme)) { $CurrentTheme = "Dark" }
$ThemeObj = $Themes[$CurrentTheme]

# =========================================================
# 6. XAML USER INTERFACE
# =========================================================
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Security Manager"
        SizeToContent="Height"
        Width="420"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanMinimize"
        WindowStyle="SingleBorderWindow"
        Background="{DynamicResource BgBrush}">

    <Window.Resources>
        <Style x:Key="ToggleSwitch" TargetType="CheckBox">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Background="Transparent" Cursor="Hand">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <ContentPresenter Grid.Column="0" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <Border Grid.Column="1" Name="Border" Width="44" Height="22" CornerRadius="11" Background="{DynamicResource ToggleOffBrush}" BorderThickness="1" BorderBrush="{DynamicResource BorderBrush}">
                                <Ellipse Name="Dot" Width="14" Height="14" HorizontalAlignment="Left" Margin="4,0,0,0" Fill="{DynamicResource ToggleThumbBrush}"/>
                            </Border>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="{DynamicResource AccentBrush}"/>
                                <Setter TargetName="Dot" Property="HorizontalAlignment" Value="Right"/>
                                <Setter TargetName="Dot" Property="Margin" Value="0,0,4,0"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Border" Property="Opacity" Value="0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="{DynamicResource InputBgBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
            <Setter Property="Padding" Value="6"/>
            <Setter Property="Margin" Value="0,10,0,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton Name="ToggleButton" Template="{DynamicResource ComboBoxToggleButton}" Focusable="false" IsChecked="{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press"/>
                            <ContentPresenter Name="ContentSite" IsHitTestVisible="False"  Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" Margin="10,3,23,3" VerticalAlignment="Center" HorizontalAlignment="Left" />
                            <Popup Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Grid Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <Border x:Name="DropDownBorder" Background="{DynamicResource SurfaceBrush}" BorderThickness="1" BorderBrush="{DynamicResource BorderBrush}"/>
                                    <ScrollViewer Margin="4,6,4,6" SnapsToDevicePixels="True">
                                        <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained" />
                                    </ScrollViewer>
                                </Grid>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <ControlTemplate x:Key="ComboBoxToggleButton" TargetType="ToggleButton">
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition /><ColumnDefinition Width="20" /></Grid.ColumnDefinitions>
                <Border x:Name="Border" Grid.ColumnSpan="2" CornerRadius="4" Background="{DynamicResource InputBgBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" />
                <Path x:Name="Arrow" Grid.Column="1" Fill="{DynamicResource TextBrush}" HorizontalAlignment="Center" VerticalAlignment="Center" Data="M 0 0 L 4 4 L 8 0 Z"/>
            </Grid>
        </ControlTemplate>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Border" Padding="5" Background="{TemplateBinding Background}">
                            <ContentPresenter />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Border" Property="Background" Value="{DynamicResource AccentBrush}"/></Trigger>
                            <Trigger Property="IsSelected" Value="True"><Setter TargetName="Border" Property="Background" Value="{DynamicResource BorderBrush}"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource SurfaceBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                 <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Opacity" Value="0.8"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,10,0,25" Cursor="Hand" Name="HeaderArea" Background="Transparent">
            <Image Name="LogoImage" Width="70" Height="70" HorizontalAlignment="Center" Margin="0,0,0,10"/>
            <TextBlock Text="System Security Manager" FontSize="20" FontWeight="SemiBold" Foreground="{DynamicResource TextBrush}" HorizontalAlignment="Center"/>
            <TextBlock Text="@osmanonurkoc" FontSize="14" Foreground="{DynamicResource SubTextBrush}" HorizontalAlignment="Center" Margin="0,5,0,0"/>
        </StackPanel>

        <StackPanel Grid.Row="1">
            <Border Background="{DynamicResource SurfaceBrush}" CornerRadius="8" Padding="15" Margin="0,0,0,15" BorderThickness="1" BorderBrush="{DynamicResource BorderBrush}">
                <StackPanel>
                    <Grid Margin="0,0,0,5">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Text="DNS Manager" FontWeight="Bold" Foreground="{DynamicResource TextBrush}" FontSize="14" VerticalAlignment="Center"/>
                        <CheckBox Name="ToggleDNS" Grid.Column="1" Style="{StaticResource ToggleSwitch}"/>
                    </Grid>
                    <TextBlock Name="StatusDNS" Text="Status: Checking..." FontSize="12" Foreground="{DynamicResource SubTextBrush}"/>
                    <StackPanel Name="PanelDNS" Visibility="Collapsed">
                         <ComboBox Name="ComboDNS" Height="35"/>
                    </StackPanel>
                </StackPanel>
            </Border>

            <Border Background="{DynamicResource SurfaceBrush}" CornerRadius="8" Padding="15" BorderThickness="1" BorderBrush="{DynamicResource BorderBrush}">
                <StackPanel>
                    <Grid Margin="0,0,0,5">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Text="Telemetry Blocker via Hosts" FontWeight="Bold" Foreground="{DynamicResource TextBrush}" FontSize="14" VerticalAlignment="Center"/>
                        <CheckBox Name="ToggleHosts" Grid.Column="1" Style="{StaticResource ToggleSwitch}"/>
                    </Grid>
                    <TextBlock Name="StatusHosts" Text="Status: Checking..." FontSize="12" Foreground="{DynamicResource SubTextBrush}"/>
                    <StackPanel Name="PanelHosts" Visibility="Collapsed" Margin="0,15,0,0">
                        <Button Name="BtnUpdate" Height="35" Cursor="Hand">
                            <StackPanel Orientation="Horizontal">
                                <Viewbox Width="14" Height="14" Margin="0,0,8,0">
                                    <Path Fill="{DynamicResource TextBrush}" Data="M5,20h14v-2H5V20z M19,9h-4V3H9v6H5l7,7L19,9z"/>
                                </Viewbox>
                                <TextBlock Text="Update Telemetry Database"/>
                            </StackPanel>
                        </Button>
                        <ProgressBar Name="ProgressHosts" Height="4" Margin="0,10,0,0" Visibility="Hidden" IsIndeterminate="True" Foreground="{DynamicResource AccentBrush}" Background="{DynamicResource BorderBrush}" BorderThickness="0"/>
                        <TextBlock Name="TxtUpdateInfo" Text="" FontSize="11" Foreground="{DynamicResource SubTextBrush}" Margin="0,5,0,0" TextWrapping="Wrap" HorizontalAlignment="Right"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </StackPanel>

        <StackPanel Grid.Row="2" VerticalAlignment="Bottom" Margin="0,15,0,10">
            <Button Name="BtnSave" Content="APPLY SETTINGS" Background="{DynamicResource AccentBrush}" Foreground="White" FontWeight="Bold" Height="40" BorderThickness="0"/>
            <TextBlock Name="TxtGlobalStatus" Text="Ready." HorizontalAlignment="Center" FontWeight="SemiBold" Foreground="{DynamicResource SubTextBrush}" FontSize="12" Margin="0,10,0,0"/>
        </StackPanel>
    </Grid>
</Window>
"@

# =========================================================
# 7. UI INITIALIZATION & BINDING
# =========================================================
$Reader = (New-Object System.Xml.XmlNodeReader $Xaml)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

$Res = $Window.Resources
$Convert = { param($Hex) return (new-object System.Windows.Media.BrushConverter).ConvertFromString($Hex) }

$Res["BgBrush"]        = &$Convert $ThemeObj.Bg
$Res["SurfaceBrush"]   = &$Convert $ThemeObj.Surface
$Res["TextBrush"]      = &$Convert $ThemeObj.Text
$Res["SubTextBrush"]   = &$Convert $ThemeObj.SubText
$Res["BorderBrush"]    = &$Convert $ThemeObj.Border
$Res["AccentBrush"]    = &$Convert $ThemeObj.Accent
$Res["ToggleOffBrush"] = &$Convert $ThemeObj.ToggleOff
$Res["ToggleThumbBrush"] = &$Convert $ThemeObj.ToggleThumb
$Res["InputBgBrush"]   = &$Convert $ThemeObj.InputBg
$Res["GreenBrush"]     = &$Convert $ThemeObj.Green
$Res["RedBrush"]       = &$Convert $ThemeObj.Red
$Res["OrangeBrush"]    = &$Convert $ThemeObj.Orange

$HeaderArea = $Window.FindName("HeaderArea")
$LogoImage = $Window.FindName("LogoImage")
$ToggleDNS = $Window.FindName("ToggleDNS")
$StatusDNS = $Window.FindName("StatusDNS")
$PanelDNS = $Window.FindName("PanelDNS")
$ComboDNS = $Window.FindName("ComboDNS")
$ToggleHosts = $Window.FindName("ToggleHosts")
$StatusHosts = $Window.FindName("StatusHosts")
$PanelHosts = $Window.FindName("PanelHosts")
$BtnUpdate = $Window.FindName("BtnUpdate")
$ProgressHosts = $Window.FindName("ProgressHosts")
$TxtUpdateInfo = $Window.FindName("TxtUpdateInfo")
$BtnSave = $Window.FindName("BtnSave")
$TxtGlobalStatus = $Window.FindName("TxtGlobalStatus")

if (![string]::IsNullOrEmpty($AppIconBase64)) {
    try {
        $IconBytes = [Convert]::FromBase64String($AppIconBase64)
        $script:IconMemStream = New-Object System.IO.MemoryStream(,$IconBytes)
        $BitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage
        $BitmapImage.BeginInit()
        $BitmapImage.StreamSource = $script:IconMemStream
        $BitmapImage.EndInit()
        $LogoImage.Source = $BitmapImage
        $DrawingBitmap = [System.Drawing.Bitmap]::FromStream($script:IconMemStream)
        $Hicon = $DrawingBitmap.GetHicon()
        $WM_SETICON = 0x0080
        $Window.Add_SourceInitialized({
            try {
                $InteropHelper = New-Object System.Windows.Interop.WindowInteropHelper($Window)
                $Hwnd = $InteropHelper.Handle
                if ($CurrentTheme -eq "Dark") {
                    $Val = 1
                    [Win32]::DwmSetWindowAttribute($Hwnd, 20, [ref]$Val, 4)
                }
                [Win32]::SendMessage($Hwnd, $WM_SETICON, [IntPtr]0, $Hicon)
                [Win32]::SendMessage($Hwnd, $WM_SETICON, [IntPtr]1, $Hicon)
            } catch {}
        })
    } catch {}
}

foreach ($key in $script:DNSProviders.Keys) { $ComboDNS.Items.Add($key) | Out-Null }
$ComboDNS.SelectedIndex = 0

# =========================================================
# 8. CORE LOGIC (HOSTS MANAGEMENT)
# =========================================================

# Helper: Native .NET attribute handling
$script:UnprotectFile = {
    param($Path)
    if ([System.IO.File]::Exists($Path)) {
        try {
            $fileInfo = New-Object System.IO.FileInfo($Path)
            if ($fileInfo.IsReadOnly) {
                $fileInfo.IsReadOnly = $false
            }
        } catch {}
    }
}

$script:GetCleanHostsContent = {
    # Ensure we can access the file
    & $script:UnprotectFile -Path $script:HostsPath

    # Check for backup using pure .NET
    if (-not [System.IO.File]::Exists($script:HostsBackupPath)) {
        try { [System.IO.File]::Copy($script:HostsPath, $script:HostsBackupPath, $true) } catch {}
    }

    if ([System.IO.File]::Exists($script:HostsPath)) {
        try {
            $content = [System.IO.File]::ReadAllText($script:HostsPath)
            if ($null -ne $content) {
                $startIndex = $content.IndexOf($script:BlockStartTag)
                $endIndex = $content.IndexOf($script:BlockEndTag)

                if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
                    $endTagLength = $script:BlockEndTag.Length
                    $cleanContent = $content.Remove($startIndex, ($endIndex - $startIndex) + $endTagLength)
                    return $cleanContent.Trim()
                }
                return $content.Trim()
            }
        } catch {}
    }
    return "127.0.0.1 localhost`r`n::1 localhost"
}

$script:RunHostsUpdate = {
    param($Silent=$false)

    $ProgressHosts.Visibility = "Visible"
    if (!$Silent) {
        $TxtGlobalStatus.Text = "Updating Telemetry database..."
        $TxtGlobalStatus.Foreground = $Res["SubTextBrush"]
    }
    $TxtUpdateInfo.Text = "Downloading list..."
    $BtnUpdate.IsEnabled = $false
    $ToggleHosts.IsEnabled = $false

    [System.Windows.Forms.Application]::DoEvents()

    try {
        $userContent = & $script:GetCleanHostsContent
        $newBlock = "`r`n`r`n" + $script:BlockStartTag + "`r`n"

        $WebClient = New-Object System.Net.WebClient
        $WebClient.Encoding = [System.Text.Encoding]::UTF8

        $uniqueHosts = New-Object System.Collections.Generic.HashSet[string]
        foreach ($url in $script:AdBlockSources) {
            try {
                $content = $WebClient.DownloadString($url)
                $lines = $content -split "`n"
                foreach ($line in $lines) {
                    $trimmedLine = $line.Trim()
                    if ($trimmedLine -notmatch "^\s*#" -and $trimmedLine -match "^(0\.0\.0\.0|127\.0\.0\.1)\s+(.+)") {
                        $domain = $matches[2].Trim()
                        [void]$uniqueHosts.Add("0.0.0.0 $domain")
                    }
                }
            } catch { }
        }
        $newBlock += ($uniqueHosts -join "`r`n") + "`r`n"
        $newBlock += $script:BlockEndTag

        # Ensure write access again before saving
        & $script:UnprotectFile -Path $script:HostsPath
        $finalContent = $userContent + "`r`n" + $newBlock

        # Native .NET write
        [System.IO.File]::WriteAllText($script:HostsPath, $finalContent)

        if (!$Silent) {
            $TxtGlobalStatus.Text = "Telemetry list updated successfully."
            $TxtGlobalStatus.Foreground = $Res["GreenBrush"]
        }

        $TxtUpdateInfo.Text = "Database is up to date! (Just Now)"
        $TxtUpdateInfo.Foreground = $Res["GreenBrush"]
    }
    catch {
        $TxtGlobalStatus.Text = "Telemetry Update Failed."
        $TxtGlobalStatus.Foreground = $Res["RedBrush"]
        $TxtUpdateInfo.Text = "Error: $($_.Exception.Message)"
        $TxtUpdateInfo.Foreground = $Res["RedBrush"]
    }
    finally {
        $ProgressHosts.Visibility = "Hidden"
        $BtnUpdate.IsEnabled = $true
        $ToggleHosts.IsEnabled = $true
    }
}

# =========================================================
# 9. STATE DETECTION
# =========================================================
$Window.Add_Loaded({
    # Check DNS
    try {
        $StatusDNS.Text = "Status: Inactive (DHCP)"

        # Try to find an active physical adapter first, then fallback to any physical
        $activeAdapter = Get-NetAdapter | Where-Object { $_.HardwareInterface -eq $true -and $_.Status -eq 'Up' } | Select-Object -First 1
        if (-not $activeAdapter) {
            $activeAdapter = Get-NetAdapter | Where-Object { $_.HardwareInterface -eq $true } | Select-Object -First 1
        }

        if ($activeAdapter) {
            $currentIPs = (Get-DnsClientServerAddress -InterfaceIndex $activeAdapter.InterfaceIndex).ServerAddresses -join ","

            # Verify if it is TRULY static via Registry (Standard IPs can confuse the check if router gives the same IP via DHCP)
            $isStatic = $false
            try {
                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($activeAdapter.InterfaceGuid)"
                $ns = (Get-ItemProperty -Path $regPath -Name "NameServer" -ErrorAction SilentlyContinue).NameServer
                if (-not [string]::IsNullOrWhiteSpace($ns)) { $isStatic = $true }
            } catch {}

            $found = $false
            if ($isStatic) {
                foreach ($key in $script:DNSProviders.Keys) {
                    if ($script:DNSProviders[$key] -eq $currentIPs) {
                        $ComboDNS.SelectedItem = $key
                        $ToggleDNS.IsChecked = $true
                        $StatusDNS.Text = "Status: Active ($key)"
                        $StatusDNS.Foreground = $Res["GreenBrush"]
                        $found = $true
                        break
                    }
                }
                if (-not $found -and $currentIPs -ne "") {
                     $StatusDNS.Text = "Status: Custom ($currentIPs)"
                }
            } else {
                 # It is DHCP, even if IPs look familiar (e.g. Router assigning 8.8.8.8)
                 $StatusDNS.Text = "Status: Inactive (DHCP)"
                 $StatusDNS.Foreground = $Res["SubTextBrush"]
            }
        }
    } catch {
        $ToggleDNS.IsChecked = $false
    }

    # Check Hosts
    try {
        $StatusHosts.Text = "Status: Inactive (Default)"
        $TxtUpdateInfo.Text = "Checking..."

        # Ensure we can read it to check status
        & $script:UnprotectFile -Path $script:HostsPath

        if ([System.IO.File]::Exists($script:HostsPath)) {
            $hContent = [System.IO.File]::ReadAllText($script:HostsPath)

            if ($hContent -match [Regex]::Escape($script:BlockStartTag)) {
                $ToggleHosts.IsChecked = $true
                $StatusHosts.Text = "Status: Active (Filtered)"
                $StatusHosts.Foreground = $Res["GreenBrush"]
                $PanelHosts.Visibility = "Visible"

                try {
                    $lastWrite = [System.IO.File]::GetLastWriteTime($script:HostsPath)
                    $TxtUpdateInfo.Text = "Last updated: $($lastWrite.ToString('dd/MM/yyyy'))"
                } catch {}
            } else {
                 $TxtUpdateInfo.Text = "Ready to enable."
            }
        }
    } catch {
        $ToggleHosts.IsChecked = $false
        $StatusHosts.Text = "Error checking hosts"
    }
})

# =========================================================
# 10. EVENT HANDLERS
# =========================================================
$HeaderArea.Add_MouseLeftButtonUp({ Start-Process "https://www.osmanonurkoc.com" })

$ToggleDNS.Add_Checked({
    $PanelDNS.Visibility = "Visible"
    $StatusDNS.Text = "Status: Active (Pending Apply)"
    $StatusDNS.Foreground = $Res["OrangeBrush"]
})
$ToggleDNS.Add_Unchecked({
    $PanelDNS.Visibility = "Collapsed"
    $StatusDNS.Text = "Status: Inactive (Pending Apply)"
    $StatusDNS.Foreground = $Res["OrangeBrush"]
})

$ToggleHosts.Add_Click({
    if ($ToggleHosts.IsChecked) {
        $PanelHosts.Visibility = "Visible"
        $StatusHosts.Text = "Status: Active (Updating...)"
        $StatusHosts.Foreground = $Res["OrangeBrush"]
        & $script:RunHostsUpdate -Silent $true
        $StatusHosts.Text = "Status: Active (Updated)"
        $StatusHosts.Foreground = $Res["GreenBrush"]
    } else {
        $PanelHosts.Visibility = "Collapsed"
        $StatusHosts.Text = "Status: Inactive (Pending Apply)"
        $StatusHosts.Foreground = $Res["OrangeBrush"]
    }
})

$BtnUpdate.Add_Click({ & $script:RunHostsUpdate -Silent $false })

$BtnSave.Add_Click({
    $BtnSave.IsEnabled = $false
    $BtnSave.Content = "APPLYING..."
    $TxtGlobalStatus.Text = "Applying settings..."
    $TxtGlobalStatus.Foreground = $Res["OrangeBrush"]
    [System.Windows.Forms.Application]::DoEvents()

    # Get all physical adapters (Ethernet & Wifi)
    $targetAdapters = Get-NetAdapter | Where-Object { $_.HardwareInterface -eq $true }

    # 1. Apply DNS
    if ($ToggleDNS.IsChecked) {
        $sel = $ComboDNS.SelectedItem
        if ($sel -eq "Default (DHCP)") {
             $targetAdapters | ForEach-Object {
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
            }
            $StatusDNS.Text = "Status: Inactive (DHCP)"
            $StatusDNS.Foreground = $Res["SubTextBrush"]
        }
        elseif ($script:DNSProviders.Contains($sel)) {
            $ips = $script:DNSProviders[$sel] -split ","
            $targetAdapters | ForEach-Object {
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $ips -ErrorAction SilentlyContinue
            }
            $StatusDNS.Text = "Status: Active ($sel)"
            $StatusDNS.Foreground = $Res["GreenBrush"]
        }
    } else {
        # Force Reset on All Adapters
        $targetAdapters | ForEach-Object {
            Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        }
        $StatusDNS.Text = "Status: Inactive (DHCP)"
        $StatusDNS.Foreground = $Res["SubTextBrush"]
    }

    # 2. Apply Hosts (Using Pure .NET File I/O)
    if (-not $ToggleHosts.IsChecked) {
        try {
            & $script:UnprotectFile -Path $script:HostsPath
            & $script:UnprotectFile -Path $script:HostsBackupPath

            if ([System.IO.File]::Exists($script:HostsBackupPath)) {
                [System.IO.File]::Copy($script:HostsBackupPath, $script:HostsPath, $true)
            }
            else {
                $clean = & $script:GetCleanHostsContent
                [System.IO.File]::WriteAllText($script:HostsPath, $clean)
            }
            $StatusHosts.Text = "Status: Inactive (Restored)"
            $StatusHosts.Foreground = $Res["SubTextBrush"]
        } catch {}
    }

    Start-Sleep -Milliseconds 500
    Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -WindowStyle Hidden

    $TxtGlobalStatus.Text = "Configuration applied successfully."
    $TxtGlobalStatus.Foreground = $Res["GreenBrush"]
    $BtnSave.Content = "APPLY SETTINGS"
    $BtnSave.IsEnabled = $true
})

$Window.ShowDialog() | Out-Null

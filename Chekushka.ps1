<#
.SYNOPSIS
    User account management tool – always queries PDC Emulator for lockout status,
    unlocks on both PDC and nearest writable DC.
.DESCRIPTION
    Searches AD users by login or surname, displays account status (locked, disabled,
    password expiry), and allows unlocking on both the PDC Emulator and the nearest DC.
.NOTES
    Release Candidate – Codename Baywatch
    Build date : 2026-07-24 17:15 UTC
    Requires ActiveDirectory module and appropriate permissions.
#>

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

# ============================
# XAML UI Definition
# ============================
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Chekushka – Baywatch" Height="560" Width="680"
        WindowStartupLocation="CenterScreen"
        Background="#F0F2F5" FontFamily="Segoe UI" FontSize="13"
        AllowsTransparency="False" WindowStyle="SingleBorderWindow"
        ResizeMode="CanResizeWithGrip">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Margin" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#005A9E"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#003D7A"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Background" Value="#B3B3B3"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="UnlockButtonStyle" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="#D83B01"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Width" Value="90"/>
            <Setter Property="Height" Value="22"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="8,2"/>
            <Setter Property="Margin" Value="4,0,0,0"/>
            <Setter Property="Visibility" Value="Hidden"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#34A853"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#2E7D32"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="Border" x:Key="CardStyle">
            <Setter Property="Background" Value="White"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="16"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect ShadowDepth="2" BlurRadius="8" Opacity="0.15"/>
                </Setter.Value>
            </Setter>
        </Style>
        <SolidColorBrush x:Key="GridLineBrush" Color="#D0D0D0"/>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header Card -->
        <Border Grid.Row="0" Style="{StaticResource CardStyle}" Margin="0,0,0,16">
            <StackPanel>
                <TextBlock Text="User Lookup (PDC Emulator)" FontWeight="SemiBold" FontSize="15"
                           Foreground="#2D2D2D" Margin="0,0,0,12"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                    <TextBlock Text="Search by:" VerticalAlignment="Center" Margin="0,0,12,0" Foreground="#444"/>
                    <RadioButton x:Name="rbLogin" Content="Login" IsChecked="True" Margin="0,0,16,0" Foreground="#222"/>
                    <RadioButton x:Name="rbSurname" Content="Surname" Foreground="#222"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal">
                    <TextBox x:Name="tbSearch" Width="320" Height="32" FontSize="13"
                             Padding="8,4" VerticalContentAlignment="Center"
                             BorderBrush="#C0C0C0" BorderThickness="1"
                             Background="#FAFAFA"/>
                    <Button x:Name="btnSearch" Content="Search" Width="100" Height="32" Margin="12,0,0,0"/>
                </StackPanel>
            </StackPanel>
        </Border>

        <!-- Results Card -->
        <Border Grid.Row="1" Style="{StaticResource CardStyle}" Margin="0,0,0,16">
            <StackPanel>
                <TextBlock Text="Information:" FontWeight="SemiBold" FontSize="15"
                           Foreground="#2D2D2D" Margin="0,0,0,12"/>
                <Border BorderBrush="{StaticResource GridLineBrush}" BorderThickness="1" CornerRadius="2">
                    <Grid Margin="0" ShowGridLines="True">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="180"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <TextBlock Grid.Row="0" Grid.Column="0" Text="User:" Margin="8,6" Foreground="#555" VerticalAlignment="Center"/>
                        <TextBlock x:Name="txtUser" Grid.Row="0" Grid.Column="1" Margin="8,6" FontWeight="SemiBold" Foreground="#1A1A1A" VerticalAlignment="Center"/>

                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Locked:" Margin="8,6" Foreground="#555" VerticalAlignment="Center"/>
                        <StackPanel Grid.Row="1" Grid.Column="1" Orientation="Horizontal" Margin="8,6" VerticalAlignment="Center">
                            <TextBlock x:Name="txtLocked" VerticalAlignment="Center" Foreground="#1A1A1A"/>
                            <Button x:Name="btnUnlock" Content="Unlock" Style="{StaticResource UnlockButtonStyle}"/>
                        </StackPanel>

                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Disabled:" Margin="8,6" Foreground="#555" VerticalAlignment="Center"/>
                        <TextBlock x:Name="txtDisabled" Grid.Row="2" Grid.Column="1" Margin="8,6" Foreground="#1A1A1A" VerticalAlignment="Center"/>

                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Account expired:" Margin="8,6" Foreground="#555" VerticalAlignment="Center"/>
                        <TextBlock x:Name="txtAccExpired" Grid.Row="3" Grid.Column="1" Margin="8,6" Foreground="#1A1A1A" VerticalAlignment="Center"/>

                        <TextBlock Grid.Row="4" Grid.Column="0" Text="Password expired:" Margin="8,6" Foreground="#555" VerticalAlignment="Center"/>
                        <TextBlock x:Name="txtPwdExpired" Grid.Row="4" Grid.Column="1" Margin="8,6" Foreground="#1A1A1A" VerticalAlignment="Center"/>

                        <TextBlock Grid.Row="5" Grid.Column="0" Text="Must change password:" Margin="8,6" Foreground="#555" VerticalAlignment="Center"/>
                        <TextBlock x:Name="txtMustChange" Grid.Row="5" Grid.Column="1" Margin="8,6" Foreground="#1A1A1A" VerticalAlignment="Center"/>
                    </Grid>
                </Border>
            </StackPanel>
        </Border>

        <!-- Status Bar -->
        <Border Grid.Row="3" Background="#E6E9ED" CornerRadius="6" Padding="10,6" Margin="0,4,0,0">
            <TextBlock x:Name="txtStatus" Foreground="#222" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/>
        </Border>
    </Grid>
</Window>
"@

# ============================
# Global Variables
# ============================
$script:PDCServer = $null
$script:DefaultMaxPasswordAge = $null
$script:CurrentSam = $null

# UI control references (set in Initialize-UI)
$script:window = $null
$script:rbLogin = $null
$script:rbSurname = $null
$script:tbSearch = $null
$script:btnSearch = $null
$script:btnUnlock = $null
$script:txtUser = $null
$script:txtDisabled = $null
$script:txtLocked = $null
$script:txtPwdExpired = $null
$script:txtAccExpired = $null
$script:txtMustChange = $null
$script:txtStatus = $null

# ============================
# UI Helpers
# ============================
function Set-StatusMessage {
    param([string]$Message, [bool]$IsError = $false)
    $script:txtStatus.Text = $Message -replace '\.+$', '' -replace '\s+$', ''
    $script:txtStatus.Foreground = if ($IsError) { 'DarkRed' } else { 'DarkGreen' }
}

function Clear-ResultFields {
    $fields = @($script:txtUser, $script:txtDisabled, $script:txtLocked,
                $script:txtPwdExpired, $script:txtAccExpired, $script:txtMustChange)
    foreach ($field in $fields) { $field.Text = '' }

    $highlightControls = @($script:txtDisabled, $script:txtLocked,
                           $script:txtPwdExpired, $script:txtAccExpired,
                           $script:txtMustChange)
    foreach ($ctrl in $highlightControls) {
        $ctrl.Foreground = '#1A1A1A'
        $ctrl.FontWeight = 'Normal'
    }

    $script:btnUnlock.Visibility = 'Hidden'
    $script:CurrentSam = $null
    Set-StatusMessage ''
}

function Set-RedBold {
    param($Control)
    $Control.Foreground = '#D83B01'
    $Control.FontWeight = 'Bold'
}

function Format-DateShort {
    param([datetime]$Date)
    $Date.ToString('dd/MM/yyyy')
}

# ============================
# AD Helpers
# ============================
function Get-PDCEmulator {
    try {
        $domain = Get-ADDomain -ErrorAction Stop
        return $domain.PDCEmulator
    }
    catch {
        throw "Unable to determine PDC Emulator: $($_.Exception.Message)"
    }
}

function Get-NearestDC {
    try {
        $currentSite = (Get-ADDomainController -Discover -ErrorAction Stop).Site
        if (-not $currentSite) { throw "Could not determine current AD site." }

        $otherDCs = Get-ADDomainController -Filter "Site -eq '$currentSite' -and IsReadOnly -eq `$false" -ErrorAction Stop |
                    Where-Object { $_.HostName -ne $script:PDCServer }

        if (-not $otherDCs) {
            $otherDCs = Get-ADDomainController -Filter "IsReadOnly -eq `$false" -ErrorAction Stop |
                        Where-Object { $_.HostName -ne $script:PDCServer }
        }

        return if ($otherDCs) { $otherDCs[0].HostName } else { $null }
    }
    catch {
        return $null
    }
}

function Get-DefaultPasswordAge {
    param([string]$PDCServer)
    try {
        $policy = Get-ADDefaultDomainPasswordPolicy -Server $PDCServer -ErrorAction Stop
        return [int]$policy.MaxPasswordAge.TotalDays
    }
    catch {
        return 120
    }
}

function Get-PasswordExpiryInfo {
    param(
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        [string]$PDCServer,
        [int]$DefaultMaxAge
    )
    try {
        $fgpp = Get-ADUserResultantPasswordPolicy -Identity $User.SamAccountName -Server $PDCServer -ErrorAction Stop
        $maxAge = [int]$fgpp.MaxPasswordAge.TotalDays
    }
    catch {
        $maxAge = $DefaultMaxAge
    }

    if ($User.PasswordNeverExpires) {
        return @{ Expired = $false; DisplayText = 'False (password never expires)' }
    }
    if ($User.pwdLastSet -eq 0) {
        return @{ Expired = $false; DisplayText = 'False (must change at next logon)' }
    }
    if (-not $User.PasswordLastSet) {
        return @{ Expired = $false; DisplayText = 'False (PasswordLastSet unknown)' }
    }

    $expiry = $User.PasswordLastSet.AddDays($maxAge)
    $expired = $expiry -lt (Get-Date)
    $display = if ($expired) {
        "True (expired on $(Format-DateShort $expiry))"
    } else {
        "False (expires on $(Format-DateShort $expiry))"
    }
    return @{ Expired = $expired; DisplayText = $display }
}

function Find-User {
    param(
        [string]$SearchValue,
        [bool]$SearchByLogin,
        [string]$PDCServer
    )
    $properties = @('Enabled', 'LockedOut', 'AccountExpirationDate',
                    'pwdLastSet', 'PasswordLastSet', 'PasswordNeverExpires',
                    'SamAccountName', 'Name')

    if ($SearchByLogin) {
        $user = Get-ADUser -Server $PDCServer -Filter "sAMAccountName -eq '$SearchValue'" -Properties $properties -ErrorAction Stop
        if (-not $user) { throw "Login '$SearchValue' not found." }
        return $user
    }
    else {
        $users = @(Get-ADUser -Server $PDCServer -Filter "sn -like '$SearchValue*'" -Properties $properties -ErrorAction Stop)
        if ($users.Count -eq 0) { throw "Surname '$SearchValue' not found." }
        if ($users.Count -eq 1) { return $users[0] }

        $selection = $users |
            Select-Object Name, SamAccountName, DistinguishedName |
            Out-GridView -Title "Select user" -PassThru

        if (-not $selection) { throw "Selection cancelled." }
        return Get-ADUser -Server $PDCServer -Identity $selection.SamAccountName -Properties $properties -ErrorAction Stop
    }
}

# ============================
# Core Actions
# ============================
function Update-UIWithUser {
    param([Microsoft.ActiveDirectory.Management.ADUser]$User)

    $script:CurrentSam = $User.SamAccountName
    $script:txtUser.Text = "$($User.Name) ($($User.SamAccountName))"

    # Locked
    if ($User.LockedOut) {
        $script:txtLocked.Text = 'True'
        Set-RedBold $script:txtLocked
        $script:btnUnlock.Visibility = 'Visible'
    } else {
        $script:txtLocked.Text = 'False'
        $script:btnUnlock.Visibility = 'Hidden'
        $script:txtLocked.Foreground = '#1A1A1A'
        $script:txtLocked.FontWeight = 'Normal'
    }

    # Disabled
    if (-not $User.Enabled) {
        $script:txtDisabled.Text = 'True'
        Set-RedBold $script:txtDisabled
    } else {
        $script:txtDisabled.Text = 'False'
        $script:txtDisabled.Foreground = '#1A1A1A'
        $script:txtDisabled.FontWeight = 'Normal'
    }

    # Account expiration
    if ($User.AccountExpirationDate) {
        if ($User.AccountExpirationDate -lt (Get-Date)) {
            $script:txtAccExpired.Text = "True (expired $(Format-DateShort $User.AccountExpirationDate))"
            Set-RedBold $script:txtAccExpired
        } else {
            $script:txtAccExpired.Text = "False (expires $(Format-DateShort $User.AccountExpirationDate))"
            $script:txtAccExpired.Foreground = '#1A1A1A'
            $script:txtAccExpired.FontWeight = 'Normal'
        }
    } else {
        $script:txtAccExpired.Text = 'False (no expiration)'
        $script:txtAccExpired.Foreground = '#1A1A1A'
        $script:txtAccExpired.FontWeight = 'Normal'
    }

    # Password expiration
    $pwdInfo = Get-PasswordExpiryInfo -User $User -PDCServer $script:PDCServer -DefaultMaxAge $script:DefaultMaxPasswordAge
    $script:txtPwdExpired.Text = $pwdInfo.DisplayText
    if ($pwdInfo.Expired) {
        Set-RedBold $script:txtPwdExpired
    } else {
        $script:txtPwdExpired.Foreground = '#1A1A1A'
        $script:txtPwdExpired.FontWeight = 'Normal'
    }

    # Must change password
    if ($User.pwdLastSet -eq 0) {
        $script:txtMustChange.Text = 'True'
        Set-RedBold $script:txtMustChange
    } else {
        $script:txtMustChange.Text = 'False'
        $script:txtMustChange.Foreground = '#1A1A1A'
        $script:txtMustChange.FontWeight = 'Normal'
    }
}

function Invoke-Search {
    Clear-ResultFields

    $searchValue = $script:tbSearch.Text.Trim()
    if (-not $searchValue) {
        Set-StatusMessage 'Please enter a search value.' -IsError $true
        return
    }

    try {
        $user = Find-User -SearchValue $searchValue `
                          -SearchByLogin $script:rbLogin.IsChecked `
                          -PDCServer $script:PDCServer
        Update-UIWithUser -User $user
        Set-StatusMessage "User loaded successfully from PDC Emulator ($($script:PDCServer))"
    }
    catch {
        Set-StatusMessage $_.Exception.Message -IsError $true
    }
}

function Invoke-Unlock {
    if (-not $script:CurrentSam) {
        Set-StatusMessage 'No user selected.' -IsError $true
        return
    }

    $pdcResult = $false
    $nearestResult = $false
    $pdcError = $null
    $nearestError = $null

    try {
        Unlock-ADAccount -Server $script:PDCServer -Identity $script:CurrentSam -ErrorAction Stop
        $pdcResult = $true
    }
    catch {
        $pdcError = $_.Exception.Message
    }

    $nearestDC = Get-NearestDC
    if ($nearestDC -and $nearestDC -ne $script:PDCServer) {
        try {
            Unlock-ADAccount -Server $nearestDC -Identity $script:CurrentSam -ErrorAction Stop
            $nearestResult = $true
        }
        catch {
            $nearestError = $_.Exception.Message
        }
    }
    else {
        if (-not $nearestDC) {
            $nearestError = "No additional DC found (skipped)."
        }
        elseif ($nearestDC -eq $script:PDCServer) {
            $nearestError = "Nearest DC was the same as PDC (skipped)."
        }
    }

    $statusLines = @()
    if ($pdcResult) { $statusLines += "✓ Unlocked on PDC ($($script:PDCServer))" }
    else { $statusLines += "✗ Failed on PDC: $pdcError" }

    if ($nearestResult) { $statusLines += "✓ Unlocked on nearest DC ($nearestDC)" }
    elseif ($nearestError) { $statusLines += "⚠ Nearest DC skip/error: $nearestError" }

    $finalStatus = $statusLines -join "`n"
    $isAnyError = (-not $pdcResult) -or (-not $nearestResult -and $nearestError -and $nearestError -notlike "*skipped*")
    Set-StatusMessage $finalStatus -IsError $isAnyError

    Invoke-Search
}

# ============================
# UI Initialisation and Startup
# ============================
function Initialize-UI {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $script:window = $window
    $script:rbLogin = $window.FindName('rbLogin')
    $script:rbSurname = $window.FindName('rbSurname')
    $script:tbSearch = $window.FindName('tbSearch')
    $script:btnSearch = $window.FindName('btnSearch')
    $script:btnUnlock = $window.FindName('btnUnlock')
    $script:txtUser = $window.FindName('txtUser')
    $script:txtDisabled = $window.FindName('txtDisabled')
    $script:txtLocked = $window.FindName('txtLocked')
    $script:txtPwdExpired = $window.FindName('txtPwdExpired')
    $script:txtAccExpired = $window.FindName('txtAccExpired')
    $script:txtMustChange = $window.FindName('txtMustChange')
    $script:txtStatus = $window.FindName('txtStatus')

    $script:btnSearch.Add_Click({ Invoke-Search })
    $script:btnUnlock.Add_Click({ Invoke-Unlock })
    $script:window.Add_KeyDown({
        if ($_.Key -eq 'Enter') { Invoke-Search }
    })
}

# ============================
# Main Entry Point
# ============================
try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    [System.Windows.MessageBox]::Show(
        "Active Directory module is required.`nPlease install RSAT or load the module manually.",
        "Missing Dependency", "OK", "Error"
    )
    exit 1
}

try {
    $script:PDCServer = Get-PDCEmulator
    $script:DefaultMaxPasswordAge = Get-DefaultPasswordAge -PDCServer $script:PDCServer
}
catch {
    [System.Windows.MessageBox]::Show($_.Exception.Message, "PDC Emulator Error", "OK", "Error")
    exit 1
}

Initialize-UI
$script:window.ShowDialog() | Out-Null
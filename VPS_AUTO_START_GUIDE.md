# VPS Auto-Start Guide for Sniper Runner EA

## Recommended VPS Providers

| Provider | Specs | Price (approx) | Link |
|----------|-------|----------------|------|
| **Contabo** | 4 vCPU / 8 GB RAM / 200 GB SSD | ~$6/mo | contabo.com |
| **Vultr** | 1 vCPU / 1 GB RAM / 25 GB SSD | ~$5/mo | vultr.com |
| **AWS Lightsail** | 2 vCPU / 2 GB RAM | ~$10/mo | aws.amazon.com/lightsail |

**Recommendation:** Contabo for best price/performance. Vultr for easier setup.

---

## Step 1: Connect to VPS via RDP

### Windows Built-in RDP Client
```
1. Press Win + R, type `mstsc`, press Enter
2. Enter your VPS IP address
3. Username: Administrator (or as provided)
4. Password: (from your VPS control panel)
```

### macOS
Install Microsoft Remote Desktop from App Store, then:
- Add PC → Enter VPS IP
- User Account: Add manually with VPS credentials

### Linux
```bash
# Install Remmina or rdesktop
sudo apt install remmina
# OR
sudo apt install rdesktop

# Connect
rdesktop -u Administrator -p YOUR_PASSWORD YOUR_VPS_IP
```

---

## Step 2: Install MetaTrader 5 on VPS

### Silent Installation (Recommended)

1. Download MT5 installer:
   ```
   https://download.metatrader.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
   ```

2. Run silent install:
   ```cmd
   mt5setup.exe /auto
   ```
   
   This installs to `C:\Program Files\MetaTrader 5\`

### Manual Installation
1. Download from your broker's website
2. Run installer, follow prompts
3. Note the install path (default: `C:\Program Files\MetaTrader 5\`)

---

## Step 3: Configure MT5 for Auto-Start

### Method A: Windows Task Scheduler (Recommended)

1. Open Task Scheduler (`taskschd.msc`)
2. Create Basic Task:
   - **Name:** MT5 Auto-Start
   - **Trigger:** When the computer starts
   - **Action:** Start a program
   - **Program:** `C:\Program Files\MetaTrader 5\terminal64.exe`
   - **Add arguments:** (leave empty or add your config if needed)

3. In Properties → General:
   - Check "Run whether user is logged on or not"
   - Check "Run with highest privileges"

4. In Properties → Conditions:
   - Uncheck "Start the task only if the computer is on AC power"

### Method B: Startup Folder

1. Press `Win + R`, type:
   ```
   shell:startup
   ```

2. Create shortcut to:
   ```
   C:\Program Files\MetaTrader 5\terminal64.exe
   ```

3. Place shortcut in startup folder

**Note:** This only works when you log in. Use Task Scheduler for true headless operation.

---

## Step 4: Configure EA Auto-Start

### 1. Set up MT5 to auto-login to your account

```
File → Open Data Folder → MQL5 → Experts
```

Copy `SniperRunner_EA_v2.mq5` (or the compiled `.ex5`) to this folder.

### 2. Create a configuration file for auto-start

Create `mt5-start.ini` in MT5 config folder:
```ini
[Settings]
Account=YOUR_ACCOUNT_NUMBER
Password=YOUR_PASSWORD
Server=YOUR_BROKER_SERVER
AutoConfiguration=false
DataServer=YOUR_BROKER_SERVER
EnableDDE=false
EnableNews=false
```

### 3. Start MT5 with config:
```cmd
"C:\Program Files\MetaTrader 5\terminal64.exe" /config:mt5-start.ini
```

---

## Step 5: Enable Auto-Trading

### In MT5 Terminal:
1. **Tools → Options → Expert Advisors**
   - ✅ Allow algorithmic trading
   - ✅ Allow DLL imports (if needed)
   - ✅ Allow WebRequest for listed URL (if using external signals)

2. **Tools → Options → Notifications**
   - Configure email/push notifications for trade alerts

### On the Chart:
1. Open chart for your target symbol (e.g., EURUSD, M15)
2. Drag SniperRunner EA from Navigator to chart
3. In EA settings, confirm:
   - MagicNumber is unique
   - LotSize appropriate for account
   - All filters enabled as desired

4. Click **AutoTrading** button (must be green/active)

---

## Step 6: Set Windows to Auto-Login (Optional)

For fully unattended operation:

### Using Registry (Advanced)
```cmd
# Open regedit
# Navigate to:
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon

# Set these values:
AutoAdminLogon = 1
DefaultUserName = Administrator
DefaultPassword = YOUR_PASSWORD
```

### Using Netplwiz (Simpler)
```cmd
1. Win + R, type `netplwiz`, press Enter
2. Uncheck "Users must enter a username and password..."
3. Enter credentials when prompted
4. Restart to test
```

---

## Step 7: Verify Setup

### Test Checklist:
- [ ] RDP connects successfully
- [ ] MT5 opens without errors
- [ ] Account auto-logs in
- [ ] EA loads on chart with correct settings
- [ ] AutoTrading button is active (green)
- [ ] Restart VPS, verify MT5 auto-starts
- [ ] Check that EA places trades (test on demo first)

### Common Issues:

| Issue | Solution |
|-------|----------|
| MT5 won't start on boot | Check Task Scheduler, verify path to terminal64.exe |
| EA not loading | Ensure .ex5 file is in MQL5\Experts folder |
| AutoTrading disabled | Check Tools → Options → Expert Advisors |
| RDP disconnects MT5 | Use `/admin` flag or configure session settings |
| VPS reboots unexpectedly | Check Windows Update schedule, disable auto-restart |

---

## Security Best Practices

1. **Firewall:** Only open RDP port (3389) if necessary, restrict by IP
2. **Strong Password:** Use 16+ character random password for VPS
3. **Updates:** Enable automatic Windows updates for security patches
4. **Backup:** Regularly export MT5 settings and EA parameters
5. **Monitoring:** Set up email alerts for disconnections or errors

---

## Quick Reference: Full Auto-Start Script

Create `start-mt5.bat` on Desktop:
```batch
@echo off
timeout /t 30 /nobreak >nul
start "" "C:\Program Files\MetaTrader 5\terminal64.exe" /config:"C:\mt5-config\mt5-start.ini"
```

Add this batch file to Task Scheduler or Startup folder.

---

## Emergency Contacts

Keep these handy:
- VPS provider support
- Broker support (for account/connection issues)
- MT5 build version number (Help → About)

**Test everything on DEMO before going LIVE.**

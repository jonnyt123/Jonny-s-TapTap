# How to Build the .ipa File

Since you don't have your Team ID handy, follow these steps in Xcode to find it and build the .ipa:

## Step 1: Open the Project
```bash
open RhythmTap.xcodeproj
```

## Step 2: Set Up Signing
1. In Xcode, select the **RhythmTap** project in the left sidebar
2. Select the **RhythmTap** target
3. Go to the **Signing & Capabilities** tab
4. Under **Team**, click the dropdown and select your Apple Developer account
   - If you don't see your account, click "Add Account..." and sign in
   - Xcode will automatically find your Team ID and set up signing
5. Change the **Bundle Identifier** from `com.yourname.rhythmtap` to something unique (e.g., `com.YOUR-NAME.rhythmtap`)

## Step 3: Archive the App
1. In Xcode's top bar, select **Any iOS Device** (or a real connected device, not a simulator)
2. Go to **Product** → **Archive**
3. Wait for the build to complete (a few minutes)
4. The **Organizer** window will open automatically

## Step 4: Export the .ipa
1. In Organizer, select your archive and click **Distribute App**
2. Choose one of these methods:
   - **Ad Hoc**: For installing on specific devices (you'll need device UDIDs)
   - **Development**: For installing via Xcode on your own devices
   - **App Store Connect**: For TestFlight or App Store
3. Click **Next** and follow the prompts
4. Choose **Automatically manage signing** (recommended)
5. Click **Export**
6. Choose where to save the .ipa file

## Step 5: Install on Your iPhone

### Option A: Using Xcode (Easiest for Development)
1. Connect your iPhone via USB
2. Select your iPhone as the destination in Xcode
3. Click the **Play** button (▶) to build and install directly

### Option B: Using the .ipa file
For **Ad Hoc** or **Development** .ipa files:
- Use tools like **Apple Configurator 2** or **Xcode's Devices window** to install the .ipa

For **TestFlight**:
- Upload to App Store Connect, then install TestFlight on your iPhone

---

**Quick tip**: If you just want to test on your iPhone, the easiest method is Option A—connect your phone and run directly from Xcode without creating an .ipa.

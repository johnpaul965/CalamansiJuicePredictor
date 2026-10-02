# Codemagic iOS Build Instructions for Calamansi Yield Predictor

This repository includes a ready-to-run `codemagic.yaml` configuration that automatically builds an iOS `.ipa` on Codemagic's Apple M1/M2 Mac virtual machines.

---

### Step 1: Sign Up / Log In to Codemagic
1. Go to **[https://codemagic.io](https://codemagic.io)**
2. Click **Sign up** or **Log in** using your GitHub / GitLab / Bitbucket account.

---

### Step 2: Connect Your Repository
1. In Codemagic, click **Add application**.
2. Select your Git provider (e.g., **GitHub**) and select this repository.
3. Select **Flutter App** as the project type.

---

### Step 3: Start the iOS Build
1. Codemagic will automatically detect the `codemagic.yaml` configuration in the root directory.
2. Select the workflow: **`iOS Unsigned / Release IPA Build`**.
3. Click **Start new build**.
4. Codemagic will:
   - Spin up an Apple Mac mini (M1).
   - Run `flutter packages pub get`.
   - Execute `flutter build ipa --release --no-codesign`.
   - Package the `.ipa` artifact.
   - Send the download link directly to your email (`johnpaultiu701@gmail.com`) and display it on the build screen under **Artifacts**.

---

### Step 4: Installing the IPA on an iPhone (Free Windows/PC Sideloading)
Because Apple restricts direct web downloads of unsigned IPAs:
1. Download the generated `.ipa` file to your Windows/Linux PC.
2. Download and open **Sideloadly** (free at [https://sideloadly.io](https://sideloadly.io)).
3. Connect your iPhone to your PC using a USB cable.
4. Drag and drop the `.ipa` file into Sideloadly.
5. Enter your regular Apple ID email and click **Start**.
6. On your iPhone: Go to **Settings > General > VPN & Device Management** > Trust your developer certificate.
7. The Calamansi Yield app is now installed on your iPhone!

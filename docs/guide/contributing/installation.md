# Installing Nylas-Mail
### Note:
If you are looking to simply install Nylas-Mail on your system (and are not looking to debug or contribute) please use one of the normal packages or installers.

## Linux -- Debain/Ubuntu
1. Install the necessary dependincies
    ```bash
    sudo apt install build-essential clang fakeroot g++-4.8 git libgnome-keyring-dev xvfb rpm libxext-dev libxtst-dev libxkbfile-dev
    ```
1. Set the following environment variables with export:
    ```bash
    export NODE_VERSION=6.9 CC=gcc-4.8 CXX=g++-4.8 DEBUG="electron-packager:*" INSTALL_TARGET=client
    ```
1. [Follow the common instructions](#common-linux-and-macos)

## Mac OS
1. Download the latest XCode from the App Store then run the following to install CLI tools
    ```bash
    xcode-select --install
    ```
1. [Follow the common instructions](#common-linux-and-macos)
      
## Common (Linux and MacOS)
1. Install Node.js version **6.9** (suggested using [NVM](https://github.com/creationix/nvm/blob/master/README.md#install-script))
    * If using nvm, prepend all the coming `npm` commands with the following to use the correct NPM version:
    ```bash
    nvm exec 6.9
    ```
1. Clone this repo using git.
    ```bash
    git clone our-repo-link
    ```
   * The repo link can be found on the main page of this repository, simply click the green "Clone or download button", and copy its contents over the "our-repo-link" in the above command.
1. Install the necessary node packages using:
    ```bash
    npm install
    ```
1. If all packages installed without errors, you can run the app with:
    ```bash
    npm start
    ```
    * If an error was thrown during the build process, please make sure all of your dependencies were installed in step 2.
    
1. Furthermore, if all dependencies were installed successfully, you can the package the app for distribution on various platforms with:
    ```bash
    npm run build-client
    ```
    * If the above command threw an error, run the following and make sure your **node version is 6.9**:
      ```bash
      node -v
      ```  

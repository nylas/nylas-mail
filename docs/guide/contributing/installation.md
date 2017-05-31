# Installing Nylas-Mail
### Note:
If you are looking to simply install Nylas-Mail on your system (and are not looking to debug or contribute) please use one of the normal packages or installers.

## Linux -- Debain/Ubuntu
1. Install Node.js version **6** (suggested using [NVM](https://github.com/creationix/nvm))
1. Install the necessary dependincies
```bash
sudo apt install build-essential clang fakeroot g++-4.8 git libgnome-keyring-dev xvfb rpm libxext-dev libxtst-dev libxkbfile-dev
```
1. Clone this repo using git.
```bash
git clone our-repo-link
```
  * The repo link can be found on the main page of this repository, simply click the green "Clone or download button", and copy its contents over the "our-repo-link" in the above command.
1. `cd` into the director that was created from the above command.
1. Install the necessary node packages using:
```bash
npm install
```
1. Assuming node was able to install the appropriate dependencies without error, you can build the client app with:
```bash
npm run build-client
```
  * If the above command threw an error, run the following and make sure your **version is less than 7, and greater than or equal to 6**:
  ```bash
  node -v
  ```  
1. If the client built without errors, you can run it with:
```bash
npm start
```
  * If an error was thrown during the build process, please make sure all of your dependencies were installed in step 2.

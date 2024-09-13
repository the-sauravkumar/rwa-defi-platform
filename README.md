# Internet Computer Web3 Application

This project is a Web3 application built using the Internet Computer (ICP) framework and React.js. It showcases various functionalities such as managing balances, transaction history, and other DeFi features through a React frontend and an ICP backend.

## Features

- Manage ICP and ckBTC balances
- View and reset transaction history
- Interact with DeFi features like buying tokens, borrowing, and repaying loans

## Installation and Setup

### Prerequisites

- **Windows 10 or higher** (version 2004 or higher)
- **64-bit machine** (System type x64-based PC)

### Steps

1. **Install Windows Subsystem for Linux (WSL):**

   - **Windows 11:** Open Command Prompt as Administrator and run:
     ```sh
     wsl --install
     ```
     For reference: [Install WSL | Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/install)

   - **Windows 10:** Follow [these instructions](https://learn.microsoft.com/en-us/windows/wsl/install) to install WSL.

2. **Install Ubuntu:**

   - Open Microsoft Store, search for **Ubuntu**, and install it.
   - Launch Ubuntu and follow the setup instructions to create a username and password.

3. **Update Ubuntu and Install Dependencies:**

   - Run the following commands:
     ```sh
     sudo apt update
     sudo apt install curl
     ```

4. **Install Node Version Manager (NVM):**

   - Run:
     ```sh
     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
     ```
   - Add NVM to your shell profile:
     ```sh
     export NVM_DIR="$HOME/.nvm"
     [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
     [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
     ```
   - Check NVM version and install Node.js:
     ```sh
     nvm --version
     source ~/.bashrc
     nvm install node
     ```

5. **Install dfx (ICP SDK):**

   - Run:
     ```sh
     sh -ci "$(curl -fsSL https://sdk.dfinity.org/install.sh)"
     ```

6. **Set Up Your ICP Project:**

   - Create a new project:
     ```sh
     mkdir ic_project
     cd ic_project
     dfx new hello
     ```
   - Navigate into the project directory:
     ```sh
     cd hello
     ```

7. **Choose Backend Language:**
   - Select from **Motoko**, **Rust**, **TypeScript**, or **Python**.

8. **Choose Frontend Framework:**
   - Select from **SvelteKit**, **React JS**, **Vanilla JS**, **No JS Template**, or **No Frontend Canister**.

9. **Develop Your Application:**
   - **Motoko Code:** Edit `src/hello_backend/main.mo`.
   - **Frontend:** For React.js development, refer to [Internet Computer React Docs](https://internetcomputer.org/docs/current/developer-docs/frontend/custom-frontend).

10. **Deploy Your Project:**

    - **Local Deployment:**
      ```sh
      dfx start --background
      dfx deploy
      ```

    - **Mainnet Deployment:**
      ```sh
      dfx start --background
      dfx deploy --network=ic
      ```

## Author

- **Saurav Kumar** *(@the-sauravkumar)*

## Contributors

- **Ankit Kumar** *(@ankits1802)*

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

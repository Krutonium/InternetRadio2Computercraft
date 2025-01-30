# Setup

1. **Server Hosting**:
    - Host the C# server either off your LAN or add an exception for it in your Computercraft config (located in `/world/serverconfig/`).

2. **Script Configuration**:
    - Edit the script to point to your C# server instance. The server runs on port 2468 by default.

3. **Network Visibility**:
   - Ensure that only the *server* is able to be able to see the C# server. Clients will be handled by Computercraft/Minecraft itself.
     - I'd suggest a firewall rule that restricts incoming connections.

4. **Running the Server on Nix**:
    - For Nix users, you can run the server with the following command:
    ```sh
    nix flake github:Krutonium/InternetRadio2Computercraft
    ```
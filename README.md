<small>:construction: This repo is still under early development.</small>

An attempt on making an RM (RPG Maker) IDE.

The name _**rrnide**_ comes from splitting __*m*__ to **_rn_**, meaning that some files of this project was part of RM itself.

## Usage

### Requirements

- To build dll: GCC and `make` in your PATH.
- To run the server: Ruby and MSYS2 in your PATH.

### Install & Run

    > make
    (rgss/mailslot.dll (x86) and mailslot/mailslot.dll (x64) are built)
    > bundle
    (Midori.rb is installed)

1. Put rgss/mailslot.dll into your project's _System_ folder.
2. Copy rgss/\*.rb into your project's script editor in order.
3. Start your project by F12. Start the web server by double click run.cmd.
4. Navigate your browser to http://localhost:8080.

**Notice:** [Midori.rb](https://github.com/midori-rb/midori.rb) is still not production-ready. You may see errors when running the server for a while. Just dirty fix them! 🤔

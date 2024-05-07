This folder contains all the editing traces benchmarked as part of this work.

The raw editing traces we used are present in DT (raw event graph) format in the raw/ folder. The `node_nodecc` and `git-makefile` traces present there were generated using the `dt git-import` command from the git repositories for nodejs and git, respectively.

The data files in this directory are all derived from the traces in raw/.

These steps require the dt CLI tool, which can be installed from the diamond types directory (mirrored in this repository) like this:

```
$ cargo install --path crates/dt-cli
```

We recommend using the version of diamond types packaged here, as it contains some tweaks that may or may not be present in the current published version of diamond types.

Once thats installed, you can create all these data files from scratch as follows:

1. Run `make_dup_data.sh` to convert raw/* to S1.dt/S2.dt/S3.dt/...
2. Run `conv.sh` to convert the .dt files into .json traces.
3. Run crdt-converter in `tools/`. `cd tools/crdt-converter && cargo run --release`. At the time of writing, this takes hours and consumes an enormous amount of RAM (32GB may be enough, but 64GB is preferable). This tool converts each file into .am .yjs variants.

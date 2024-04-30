# CRDT converter

This is a simple, hacky tool to convert from positional CRDT data to Automerge + Yjs CRDT files. This is useful for some testing & benchmarking.

This is exploratory code written to test a simple concept. Do not expect it to be maintained or updated.

License: ISC if relevant

Note this tool is a bit hacky. Since Automerge and Yjs have slightly different ordering algorithms, some datasets end up with slightly different results. (Ie, some characters appear in slightly different orders in the resulting documents). I'm counting on this not affecting benchmarking results - since a few characters in slightly different positions should hardly matter. But its not an exact 1:1 conversion. At least, not for all data sets.

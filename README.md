
There is a program 'tsort' from coreutils package. I've met it before but
never read its info page. There is a section about the tool history.

> ‘tsort’ exists because very early versions of the Unix linker processed an
> archive file exactly once, and in order.  As ‘ld’ read each object in the
> archive, it decided whether it was needed in the program based on whether it
> defined any symbols which were undefined at that point in the link.

> The way to address this problem was to first generate a set of dependencies
> of one object file on another.  This was done by a shell script called
> ‘lorder’.

> Then you ran ‘tsort’ over the ‘lorder’ output, and you used the resulting
> sort to define the order in which you added objects to the archive.

I've checked coreutils 'tsort' and OpenBSD 'tsort' source code both are quite
sophisticated. Here is lite 'tsort' awk implementation. It works the same way
as the original tool.

It takes a list of pairs of node names representing directed arcs in a graph
and prints the nodes in topological order on standard output.
It implements two algos for topological sort DFS and Kahn, Kahn is default.

Cycles are treated as errors. DFS detects cycles and resolves them by its
design, it only needs to mark inprogress nodes and check the mark in the next
descent call.

Kahn is a different beast. It has no a builtin feature to detect cycles. To
print all nodes Kahn needs to be extended with a cycle breaker. When a cycle
is detected first it looks for a node with a minimum degree (minimum number of
references to the node) then unlinks the node from nodes who reference it and
repeats sorting. Probably the approach is naive but works with resolution of
complete graphs, check samples in comp folder.


```
$ ./tsort.awk < graph
```

Use DFS instead of Kahn:

```
$ DFS= ./tsort.awk < graph
```

Show internal vertex representation:

```
$ SHOW= ./tsort.awk < graph
```

Generate svg image for the graph (need dot from graphviz):

```
$ ./graph2dot.sh graph | dot -T svg -o graph.svg
```

![Image](graph.svg)




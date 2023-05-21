#!/usr/bin/awk -f

function vertex_do_index(v,         vi)
{
    if (v in vertex2index) {
        return vertex2index[v]
    }

    vi = vertex_total++
    vertex2index[v] = vi
    vertex[vi] = v
    # '#' number of children (out-edges), 0 for leaf
    vertex[vi, "#"] = 0
    # 'd' degree for Kahn algo
    vertex[vi, "d"] = 0
    # 's' for vertex state for DFS algo
    vertex[vi, "s"] = NOTVISITED

    return vi
}

function vertex_add(vert, edge,         vi, ei, child)
{
    vi = vertex_do_index(vert)
    ei = vertex_do_index(edge)

    child = vertex[vi, "#"]++
    vertex[vi, child] = ei
    # increase the reference counter to edge
    vertex[ei, "d"] += 1
}

function vertex_show(   i, j, children)
{
    for (i = 0; i < vertex_total; i++) {
        printf("%4d: %s", i, vertex[i])
        children = vertex[i, "#"]
        if (children) {
            printf(" (")
            for (j = 0; j < children; j++) {
                printf(" %s ", vertex[vertex[i, j]])
            }
            printf(")")
        }
        printf(" [ %d ]\n", vertex[i, "d"])
    }
}

function err(msg)
{
    print "error:", msg >> "/dev/stderr"
}

function dfs(i,         children, child)
{
    # vertex is visited
    if (vertex[i, "s"] > 0) {
        if (vertex[i, "s"] == VISITED + INPROGRESS) {
            err("cycle is detected for '" vertex[i] "'") 
            cycle_detected = 1
            return -1
        }
        return 0
    }

    vertex[i, "s"] = VISITED + INPROGRESS
    children = vertex[i, "#"]

    # iterate over children with dfs()
    for (child = 0; child < children; child++) {
        if (dfs(vertex[i, child]) < 0) {
            break;
        }
    }

    vertex[i, "s"] = VISITED
    # for the right order we need to reverse visited vertices,
    # there are many right ways to do it but let use mighty awk
    # feature and pipe data to tac
    # since the command is openned only once we can pipe data
    # from the recursive function to tac
    print vertex[i] | "tac"

    return 0
}

function dfs_tsort(     i)
{
    for (i = 0; i < vertex_total; i++) {
        # depth first search
        if (dfs(i) < 0) {
            break
        }
    }
    # don't forget to close the command stream
    close("tac")
}

function kahn_tsort(      i, queue, head, tail, vi, children, child, ordered_total)
{
    # head and tail indices for a queue
    head = tail = 0

    # enqueue root vertices
    for (i = 0; i < vertex_total; i++) {
        if (vertex[i, "d"] == 0) {
            queue[tail++] = i
        }
    }

    ordered_total = 0

    while (head != tail) {
        # dequeue vertex
        vi = queue[head]
        delete queue[head++]

        # normalize queue indecies
        if (head == tail) {
            head = tail = 0;
        }

        children = vertex[vi, "#"]
        for (child = 0; child < children; child++) {
            # decrease the child vertex degree
            vertex[vertex[vi, child], "d"] -= 1
            if (vertex[vertex[vi, child], "d"] == 0) {
                # enqueue the vertex when no more reference
                queue[tail++] = vertex[vi, child]
            }
        }

        print vertex[vi]
        ++ordered_total
    }

    if (vertex_total != ordered_total) {
        err("cycle is detected")
        cycle_detected = 1
    }
}

BEGIN {
    # enum for vertex state (only dfs algo)
    NOTVISITED = 0x00
    VISITED = 0x01
    INPROGRESS = 0x02
   
    vertex_total = 0 
    cycle_detected = 0

    while (getline > 0) {
        if (NF % 2 != 0) {
            err(NR ": even number of fields is expected")
            exit 1
        }
        for (count = 1; count <= NF; count += 2) {
            vertex_add($count, $(count + 1))
        }
    }

    if ("SHOW" in ENVIRON) {
        vertex_show()
    } else if ("DFS" in ENVIRON) {
        dfs_tsort()   
    } else {
        kahn_tsort()   
    }

    exit cycle_detected
}


#!/usr/bin/awk -f

function err(msg)
{
    print "error:", msg >> "/dev/stderr"
}

function assert(cond, msg)
{
    if (!cond) {
        print "assert: " msg >> "/dev/stderr"
        exit 2
    }
}

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
    # 'd' degree for Kahn algo (number of in-edges)
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

function dfs(i,         children, child)
{
    # vertex is visited
    if (vertex[i, "s"] > 0) {
        if (vertex[i, "s"] == VISITED + INPROGRESS) {
            err("cycle is detected for '" vertex[i] "'") 
            cycle_detected = 1
        }
        return
    }

    vertex[i, "s"] = VISITED + INPROGRESS
    children = vertex[i, "#"]

    # iterate over children with dfs()
    for (child = 0; child < children; child++) {
        dfs(vertex[i, child])
    }

    vertex[i, "s"] = VISITED
    # for the right order we need to reverse visited vertices,
    # there are many right ways to do it but let use mighty awk
    # feature and pipe data to tac
    # since the command is openned only once we can pipe data
    # from the recursive function to tac
    print vertex[i] | "tac"
}

function dfs_tsort(     i)
{
    for (i = 0; i < vertex_total; i++) {
        # depth first search
        dfs(i)
    }
    # don't forget to close the command stream
    close("tac")
}

function find_min_degree_vi(      i, d, min_d_vi)
{
    min_d_vi = -1

    for (i = 0; i < vertex_total; i++) {
        d = vertex[i, "d"]
        if (d < 0) {
            continue
        }

        assert(d != 0, "degree can't be 0 when search for min degree index")
        # the best candidate with a single reference
        if (d == 1) {
            min_d_vi = i
            break
        }

        if (min_d_vi == -1 || d < vertex[min_d_vi, "d"]) {
            min_d_vi = i
        }
    }

    assert(min_d_vi != -1, "can't find node with min degree")
    return min_d_vi
}

function graph_break_cycle(       min_d_vi, i, child, children)
{
    min_d_vi = find_min_degree_vi()
    err("cycle is detected for '" vertex[min_d_vi] "'")

    for (i = 0; i < vertex_total; i++) {
        # nodes with negative degree are already processed
        if (vertex[i, "d"] < 0) {
            continue
        }

        children = vertex[i, "#"]

        for (child = 0; child < children; child++) {
            if (vertex[i, child] == min_d_vi) {
                #print "# unlink", vertex[min_d_vi], "from", vertex[i]
                assert(vertex[min_d_vi, "d"] > 0, "bad degree when unlink")
                vertex[min_d_vi, "d"] -= 1
            }
        }
    }
}

function do_kahn(      i, queue, head, tail, vi, children, child, ordered)
{
    # head and tail indices for a queue
    head = tail = 0

    # enqueue root vertices
    for (i = 0; i < vertex_total; i++) {
        if (vertex[i, "d"] == 0) {
            # treat negative as processed
            vertex[i, "d"] -=1
            queue[tail++] = i
        }
    }

    ordered = 0

    while (head != tail) {
        # dequeue vertex
        vi = queue[head]
        delete queue[head++]

        # normalize queue indices
        if (head == tail) {
            head = tail = 0;
        }

        children = vertex[vi, "#"]

        for (child = 0; child < children; child++) {
            # negative is part of a cycle which is already broken and the node
            # is processed
            if (vertex[vertex[vi, child], "d"] < 0) {
                continue
            }

            # decrease the child vertex degree
            vertex[vertex[vi, child], "d"] -= 1
            if (vertex[vertex[vi, child], "d"] == 0) {
                vertex[vertex[vi, child], "d"] -= 1
                # enqueue the vertex when no more reference
                queue[tail++] = vertex[vi, child]
            }
        }

        print vertex[vi]
        ordered += 1
    }

    if (ordered != vertex_total) {
        cycle_detected = 1
    }

    return ordered
}

function kahn_tsort(     ordered)
{
    ordered = do_kahn()

    while (ordered != vertex_total) {
        graph_break_cycle()
        ordered += do_kahn()
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


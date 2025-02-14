using Test
using Redis: RedisConnection
using RedisGraph: Graph, Node, Edge, Path, addnode!, addedge!, commit, delete, query


function creategraph()
    db_conn = RedisConnection()
    g = Graph("TestGraph", db_conn)
    return g
end


function simplerelation!(g::Graph)
    node1 = Node("FirstSimpleNode", Dict("IntProp" => 1, "StringProp" => "node prop", "BoolProp" => true))
    node2 = Node("SecondSimpleNode")
    edge = Edge("SimpleEdge", node1, node2, Dict("IntProp" => 1, "StringProp" => "node prop", "BoolProp" => false))

    addnode!(g, node1)
    addnode!(g, node2)
    addedge!(g, edge)
    res = commit(g)
end


function deletegraph!(g::Graph)
    delete(g)
end


@testset "RedisGraph.jl tests" begin
    @testset "check simple types" begin
        g = creategraph()
        @test query(g, "RETURN null").results[1] === nothing
        @test query(g, "RETURN 2").results[1] == 2
        @test query(g, "RETURN 2.0").results[1] == 2.0
        @test query(g, "RETURN true").results[1] == true
        @test query(g, "RETURN [1, 2, 'test', 3.0, false]").results[1] == [1, 2, "test", 3.0, false]
    end
    @testset "check simple relation" begin
        g = creategraph()
        try
            simplerelation!(g)

            q = query(g, "MATCH (n1)-[e]->(n2) RETURN n1, e, n2").results
            node1, edge, node2 = q[1:3]
            
            @test typeof(node1) == Node
            @test node1.label == "FirstSimpleNode"
            @test node1.properties == Dict("IntProp" => 1, "StringProp" => "node prop", "BoolProp" => true)
            @test typeof(edge) == Edge
            @test edge.relation == "SimpleEdge"
            @test edge.properties == Dict("IntProp" => 1, "StringProp" => "node prop", "BoolProp" => false)
            @test edge.src_node == node1
            @test edge.dest_node == node2
            @test typeof(node2) == Node
            @test node2.label == "SecondSimpleNode"
        finally
            deletegraph!(g)
        end
    end
    @testset "check path type" begin
        g = creategraph()
        try
            node1 = Node("FirstSimpleNode", Dict("IntProp" => 1, "StringProp" => "node prop", "BoolProp" => true))
            node2 = Node("SecondSimpleNode")
            edge = Edge("SimpleEdge", node1, node2, Dict("IntProp" => 1, "StringProp" => "node prop", "BoolProp" => false))
        
            addnode!(g, node1)
            addnode!(g, node2)
            addedge!(g, edge)
            res = commit(g)

            result_path = query(g, "MATCH p=(n1)-[e]->(n2) RETURN p").results[1]

            @test typeof(result_path) == Path
            @test result_path.nodes == Path([node1, node2], [edge]).nodes
            # it's not clear how to check edges in this case
            # @test result_path.edges == Path([node1, node2], [edge]).edges
        finally
            deletegraph!(g)
        end
    end
end

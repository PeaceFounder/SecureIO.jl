using SecureIO
using Sockets

import Sockets.TCPSocket
import SecureIO: serialize, deserialize
import Serialization

serialize(io::Union{TCPSocket,IOBuffer},msg) = Serialization.serialize(io,msg)
deserialize(io::Union{TCPSocket,IOBuffer}) = Serialization.deserialize(io)

import Multiplexers: Line, route

import Multiplexers
serialize(io::Line,msg) = Multiplexers.serialize(io,msg)
deserialize(io::Line) = Multiplexers.deserialize(io)
Multiplexers.serialize(io::SecureSerializer,msg) = serialize(io,msg)
Multiplexers.deserialize(io::SecureSerializer) = deserialize(io)

key = 12434434
N = 2

@sync begin
    @async let
        routers = listen(2001)
        try
            @show "Router"
            serversocket = accept(routers)
            secureserversocket = SecureSerializer(serversocket,key)

            lines = [Line(secureserversocket,i) for i in 1:N]
            task = @async route(lines,secureserversocket)

            susersockets = []
            for i in 1:N
                push!(susersockets,SecureSerializer(lines[i],key))
            end

            for i in 1:N
                serialize(susersockets[i],"A secure message from the router")
                @show deserialize(susersockets[i])
            end
            
            serialize(secureserversocket,:Terminate)
            
            wait(task)
        finally
            close(routers)
        end
    end

    @async let
        servers = listen(2000)
        try 
            @show "Server"
            routersocket = connect(2001)
            secureroutersocket = SecureSerializer(routersocket,key)
            
            usersockets = IO[]

            while length(usersockets)<N
                socket = accept(servers)
                push!(usersockets,SecureSerializer(socket,key))
            end

            route(usersockets,secureroutersocket)
        finally
            close(servers)
        end
    end

    @async let
        @show "User 1"
        usersocket = connect(2000)
        securesocket = SecureSerializer(usersocket,key)

        sroutersocket = SecureSerializer(securesocket,key)
        @show deserialize(sroutersocket)
        serialize(sroutersocket,"A scuere msg from user 1")
    end

    @async let
        @show "User 2"
        usersocket = connect(2000)
        securesocket = SecureSerializer(usersocket,key)
        
        sroutersocket = SecureSerializer(securesocket,key)
        @show deserialize(sroutersocket)
        serialize(sroutersocket,"A scuere msg from user 2")
    end
end



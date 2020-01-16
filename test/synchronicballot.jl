using SecureIO
using Sockets

import Sockets.TCPSocket
import SecureIO: serialize, deserialize
import Serialization

import Multiplexers: Multiplexer, Line

import Multiplexers
Multiplexers.serialize(io::SecureSerializer,msg) = serialize(io,msg)
Multiplexers.deserialize(io::SecureSerializer) = deserialize(io)

import SecureIO.Socket
import Serialization
Socket(socket::TCPSocket) = Socket(socket,Serialization.serialize,Serialization.deserialize) 
Socket(socket::Line) = Socket(socket,Multiplexers.serialize,Multiplexers.deserialize) 

key = 12434434
N = 2

@sync begin
    @async let
        routers = listen(2001)
        try
            @show "Router"
            serversocket = Socket(accept(routers))
            secureserversocket = SecureSerializer(serversocket,key)
            
            mux = Multiplexer(secureserversocket,N)

            susersockets = []
            for i in 1:N
                push!(susersockets,SecureSerializer(Socket(mux.lines[i]),key))
            end

            for i in 1:N
                serialize(susersockets[i],"A secure message from the router")
                @show deserialize(susersockets[i])
                
                @async serialize(susersockets[i],"Hello from router")
                @show deserialize(susersockets[i])
            end
            
            close(mux)
        finally
            close(routers)
        end
    end

    @async let
        servers = listen(2000)
        try 
            @show "Server"
            routersocket = Socket(connect(2001))
            secureroutersocket = SecureSerializer(routersocket,key)
            
            usersockets = IO[]

            while length(usersockets)<N
                socket = Socket(accept(servers))
                push!(usersockets,SecureSerializer(socket,key))
            end

            mux = Multiplexer(secureroutersocket,usersockets)
            wait(mux)
        finally
            close(servers)
        end
    end

    @async let
        @show "User 1"
        usersocket = Socket(connect(2000))
        securesocket = SecureSerializer(usersocket,key)

        sroutersocket = SecureSerializer(securesocket,key)
        @show deserialize(sroutersocket)
        serialize(sroutersocket,"A scuere msg from user 1")

        @async serialize(sroutersocket,"Hello user 1")
        @show deserialize(sroutersocket)
    end

    @async let
        @show "User 2"
        usersocket = Socket(connect(2000))
        securesocket = SecureSerializer(usersocket,key)
        
        sroutersocket = SecureSerializer(securesocket,key)
        @show deserialize(sroutersocket)
        serialize(sroutersocket,"A scuere msg from user 2")

        @async serialize(sroutersocket,"Hello user 2")
        @show deserialize(sroutersocket)
    end
end




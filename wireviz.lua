do
    local gv = require("gv")
        --helper function for to check if element is in table 
        --http://stackoverflow.com/questions/2282444/how-to-check-if-a-table-contains-an-element-in-lua 
        function table.contains(table, element)
            for _, value in pairs(table) do 
                if value == element then
                    return true 
                end
            end
            return false
        --end of table.contains function 
        end

        -- we want the src of the arp packet (remember arp doesn't have an IP header)
        local tcp_stream = Field.new("tcp.stream")
        --get the eth and ip src so we can map them local eth_src = Field.new("eth.src")
        local ip = Field.new("ip")
        local ip_src = Field.new("ip.src") local ip_dst = Field.new("ip.dst")
        --we can do basic service analysis
        local tcp = Field.new("tcp")
        local tcp_src = Field.new("tcp.srcport") local tcp_dst = Field.new("tcp.dstport")
        local udp = Field.new("udp")
        local udp_src = Field.new("udp.srcport") local udp_dst = Field.new("udp.dstport")
        --{ STREAMIDX:
        -- {
        -- SRCIP: srcip,
        -- DSTIP: dstip,
        -- SRCP: srcport,
        -- DSTP: dstport,
        -- TCP: bool
        -- } --}
        streams = {}

        -- create our function to run that creates the listener 
        local function init_listener()
            -- create our listener with no filter so we get all frames 
            local tap = Listener.new(nil, nil)
            -- called for every packet
            function tap.packet(pinfo, tvb, root)
                local tcpstream = tcp_stream()
                local udp = udp() 
                local ip = ip()
                if tcpstream then
                --if we have already processed this stream then
                    if streams[tostring(tcpstream)] then 
                        return
                    end
        
        --calling tostring as we assume if there is a tcp stream we have an ip header
                    local ipsrc = tostring(ip_src()) local ipdst = tostring(ip_dst())
                    local tcpsrc = tostring(tcp_src()) local tcpdst = tostring(tcp_dst())
        --build out the stream info table 
                    local streaminfo = {} 
                    streaminfo["ipsrc"] = ipsrc 
                    streaminfo["ipdst"] = ipdst 
                    streaminfo["psrc"] = tcpsrc 
                    streaminfo["pdst"] = tcpdst 
                    streaminfo["istcp"] = true
                    streams[tostring(tcpstream)] = streaminfo
                end
                if udp and ip then
            --calling tostring as we assume if there is a tcp stream we have an ip header
                    local ipsrc = tostring(ip_src()) 
                    local ipdst = tostring(ip_dst())
                    local udpsrc = tostring(udp_src()) 
                    local udpdst = tostring(udp_dst())
            --a 'udp stream' will just be a key that is the ip:port:ip:port 
                    local udp_streama = ipsrc .. udpsrc .. ipdst .. udpdst
                    local udp_streamb = ipdst .. udpdst .. ipsrc .. udpsrc
            --we processed this 'stream' already
                    if streams[udp_streama] or streams[udp_streamb] then
                        return 
                    end
        --build out the stream info table 
                local streaminfo = {} 
                streaminfo["ipsrc"] = ipsrc 
                streaminfo["ipdst"] = ipdst 
                streaminfo["psrc"] = udpsrc 
                streaminfo["pdst"] = udpdst 
                streaminfo["istcp"] = false
                streams[udp_streama] = streaminfo 
            end
        --end of tap.packet() 
        end
        -- just defining an empty tap.reset function 
        function tap.reset()
        --end of tap.reset() 
        end
        -- define the draw function to print out our created arp cache 
        function tap.draw()
        --create a graphviz unigraph 
            G = gv.graph("wireviz.lua")
            for k,v in pairs(streams) do
                local streaminfo = streams[k]
        --create nodes for src and dst ip
                local tmp_s = gv.node(G, streaminfo["ipsrc"]) 
                local tmp_d = gv.node(G, streaminfo["ipdst"])
        --lets connect them up
                local tmp_e = gv.edge(tmp_s, tmp_d) 
                gv.setv(tmp_s, "URL", "")
                local s_tltip = gv.getv(tmp_s, "tooltip") 
                local d_tltip = gv.getv(tmp_d, "tooltip")
                gv.setv(tmp_s, "tooltip", s_tltip .. "\n" .. streaminfo["psrc"])
                gv.setv(tmp_d, "tooltip", d_tltip .. "\n" .. streaminfo["pdst"])
                if streaminfo["istcp"] then 
                    gv.setv(tmp_e, "color", "red")
                else
                    gv.setv(tmp_e, "color", "green")
                end 
            end
        --gv.setv(G, "concentrate", "true") 
            gv.setv(G, "overlap", "scale") 
            gv.setv(G, "splines", "true") 
            gv.layout(G, "neato")
            gv.render(G, "svg")
        --end of tap.draw() 
        end
    --end of init_listener() 
    end
    -- call the init_listener function 
    init_listener()
--end of everything 
end
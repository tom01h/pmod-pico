`timescale 1ns/1ns
module tb ();

    logic          M_AXI_ACLK;
    logic          M_AXI_ARESETN;

    logic [31 : 0] M_AXI_AWADDR;
    logic [7 : 0]  M_AXI_AWLEN;
    logic [2 : 0]  M_AXI_AWSIZE;
    logic [1 : 0]  M_AXI_AWBURST;
    logic [2 : 0]  M_AXI_AWPROT;
    logic          M_AXI_AWVALID;
    logic          M_AXI_AWREADY;

    logic [63 : 0] M_AXI_WDATA;
    logic [7 : 0]  M_AXI_WSTRB;
    logic          M_AXI_WLAST;
    logic          M_AXI_WVALID;
    logic          M_AXI_WREADY;

    logic          M_AXI_BVALID;
    logic          M_AXI_BREADY;

    logic [31 : 0] M_AXI_ARADDR;
    logic [7 : 0]  M_AXI_ARLEN;
    logic [2 : 0]  M_AXI_ARSIZE;
    logic [1 : 0]  M_AXI_ARBURST;
    logic [2 : 0]  M_AXI_ARPROT;
    logic          M_AXI_ARVALID;
    logic          M_AXI_ARREADY;
    logic [63 : 0] M_AXI_RDATA;

    logic          M_AXI_RLAST;
    logic          M_AXI_RVALID;
    logic          M_AXI_RREADY;

    always begin
        M_AXI_ACLK=1;#5;
        M_AXI_ACLK=0;#5;
    end

    assign M_AXI_BVALID  = 1'b0;
    assign M_AXI_ARREADY = 1'b1;

    always begin
        M_AXI_AWREADY = 1'b1;
        repeat(3)@(posedge M_AXI_ACLK);
        //M_AXI_AWREADY = 1'b0;
        repeat(1)@(posedge M_AXI_ACLK);
    end
    always begin
        M_AXI_WREADY = 1'b1;
        repeat(5)@(posedge M_AXI_ACLK);
        //M_AXI_WREADY = 1'b0;
        repeat(1)@(posedge M_AXI_ACLK);
    end

    initial begin
        M_AXI_ARESETN = 1'b0;
        repeat(3)@(posedge M_AXI_ACLK);
        M_AXI_ARESETN = 1'b1;
        repeat(3)@(posedge M_AXI_ACLK);

    end
    
    logic          pck;
    logic          pwrite;
    logic [1:0]    pwd;
    logic [1:0]    prd;
    logic          pwait;
    logic          pmod_enable = 1'b0;
    integer        i,j;
    logic [9:0]    len = 'd4;
    logic [31:0]   waddress = 32'h4060_0004;
    logic [7:0]    wdata;
    logic [31:0]   raddress = 32'h4000_0000;
    always begin
        pck = pmod_enable;
        #27;
        pck = 1'b0;
        #27;
    end
    initial begin
        pmod_enable = 1'b0;
        pwrite      = 1'b0;
        pwd         = 2'b00;
        M_AXI_RVALID  = 1'b0;
        M_AXI_RLAST   = 1'b0;
        repeat(10)@(posedge M_AXI_ACLK);
        pmod_enable = 1'b1;
        pwrite = 1'b0;
        for(j=0; j<5; j++) begin
            @(posedge pck);
            pwd = len[2*j +: 2];
        end
        for(j=0; j<16; j++) begin
            @(posedge pck);
            pwd = raddress[2*j +: 2];
        end

        wait(M_AXI_ARVALID);
        repeat(2) @(posedge M_AXI_ACLK);
        M_AXI_RVALID  = 1'b1;
        M_AXI_RLAST   = 1'b1;
        M_AXI_RDATA   = 32'hdeadbeef;
        @(posedge M_AXI_ACLK);
        M_AXI_RVALID  = 1'b0;
        M_AXI_RLAST   = 1'b0;


        wait(~pwait);
        repeat(16) @(posedge pck);
        /*pwrite = 1'b1;
        for(i=0; i<14; i++) begin
            casez(i)
                'd0:  wdata = 8'h68;
                'd1:  wdata = 8'h65;
                'd2:  wdata = 8'h6C;
                'd3:  wdata = 8'h6C;
                'd4:  wdata = 8'h6F;
                'd5:  wdata = 8'h2C;
                'd6:  wdata = 8'h20;
                'd7:  wdata = 8'h77;
                'd8:  wdata = 8'h6F;
                'd9:  wdata = 8'h72;
                'd10: wdata = 8'h6C;
                'd11: wdata = 8'h64;
                'd12: wdata = 8'h0D;
                'd13: wdata = 8'h0A;
            endcase
            for(j=0; j<5; j++) begin
                @(posedge pck);
                pwd = len[2*j +: 2];
            end
            for(j=0; j<16; j++) begin
                @(posedge pck);
                pwd = waddress[2*j +: 2];
            end
            for(j=0; j<4; j++) begin
                @(posedge pck);
                pwd = wdata[2*j +: 2];
            end
            for(j=0; j<12; j++) begin
                @(posedge pck);
                pwd = 0;
            end
        end*/
        pmod_enable = 1'b0;

        repeat(100)@(posedge M_AXI_ACLK);
        $finish;
    end
    
    pmodIf pmodIf (
        .M_AXI_ACLK(M_AXI_ACLK),
        .M_AXI_ARESETN(M_AXI_ARESETN),
        
        .M_AXI_AWADDR(M_AXI_AWADDR),
        .M_AXI_AWLEN(M_AXI_AWLEN),
        .M_AXI_AWSIZE(M_AXI_AWSIZE),
        .M_AXI_AWBURST(M_AXI_AWBURST),
        .M_AXI_AWPROT(M_AXI_AWPROT),
        .M_AXI_AWVALID(M_AXI_AWVALID),
        .M_AXI_AWREADY(M_AXI_AWREADY),
        
        .M_AXI_WDATA(M_AXI_WDATA),
        .M_AXI_WSTRB(M_AXI_WSTRB),
        .M_AXI_WLAST(M_AXI_WLAST),
        .M_AXI_WVALID(M_AXI_WVALID),
        .M_AXI_WREADY(M_AXI_WREADY),
        
        .M_AXI_BVALID(M_AXI_BVALID),
        .M_AXI_BREADY(M_AXI_BREADY),     

        .M_AXI_ARADDR(M_AXI_ARADDR),
        .M_AXI_ARLEN(M_AXI_ARLEN),
        .M_AXI_ARSIZE(M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),
        .M_AXI_ARPROT(M_AXI_ARPROT),
        .M_AXI_ARVALID(M_AXI_ARVALID),
        .M_AXI_ARREADY(M_AXI_ARREADY),
        
        .M_AXI_RDATA(M_AXI_RDATA),
        .M_AXI_RLAST(M_AXI_RLAST),
        .M_AXI_RVALID(M_AXI_RVALID),
        .M_AXI_RREADY(M_AXI_RREADY),
        
        .pck(pck),
        .pwrite(pwrite),
        .pwd(pwd),
        .prd(prd),
        .pwait(pwait)
    );

endmodule
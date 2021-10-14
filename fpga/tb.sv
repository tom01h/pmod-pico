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

    logic          button;

    always begin
        M_AXI_ACLK=1;#5;
        M_AXI_ACLK=0;#5;
    end

    assign M_AXI_BVALID  = 1'b0;
    assign M_AXI_ARREADY = 1'b1;

    assign M_AXI_RDATA   = 64'h0;
    assign M_AXI_RLAST   = 1'b0;
    assign M_AXI_RVALID  = 1'b0;

    always begin
        M_AXI_AWREADY = 1'b1;
        repeat(3)@(posedge M_AXI_ACLK);
        M_AXI_AWREADY = 1'b0;
        repeat(1)@(posedge M_AXI_ACLK);
    end
    always begin
        M_AXI_WREADY = 1'b1;
        repeat(5)@(posedge M_AXI_ACLK);
        M_AXI_WREADY = 1'b0;
        repeat(1)@(posedge M_AXI_ACLK);
    end

    initial begin
        M_AXI_ARESETN = 1'b0;
        button        = 1'b0;
        repeat(3)@(posedge M_AXI_ACLK);
        M_AXI_ARESETN = 1'b1;
        repeat(3)@(posedge M_AXI_ACLK);
        button        = 1'b1;
        repeat(3)@(posedge M_AXI_ACLK);
        button        = 1'b0;
        repeat(20)@(posedge M_AXI_ACLK);
        button        = 1'b1;
        repeat(3)@(posedge M_AXI_ACLK);
        button        = 1'b0;
    end
    
    integer cnt_a, cnt_d;
    
    always_ff @(posedge M_AXI_ACLK) begin
        if(~M_AXI_ARESETN) begin cnt_a = 0; cnt_d = 0; end
        if(M_AXI_AWREADY & M_AXI_AWVALID) cnt_a = cnt_a + 1;
        if(M_AXI_WREADY  & M_AXI_WVALID)  cnt_d = cnt_d + 1;
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
        
        .button(button)
    );

endmodule
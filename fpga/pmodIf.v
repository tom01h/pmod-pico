module pmodIf (
    input wire           M_AXI_ACLK,
    input wire           M_AXI_ARESETN,

    output wire [31 : 0] M_AXI_AWADDR,
    output wire [7 : 0]  M_AXI_AWLEN,
    output wire [2 : 0]  M_AXI_AWSIZE,
    output wire [1 : 0]  M_AXI_AWBURST,
    output wire [2 : 0]  M_AXI_AWPROT,
    output wire          M_AXI_AWVALID,
    input wire           M_AXI_AWREADY,

    output wire [63 : 0] M_AXI_WDATA,
    output wire [7 : 0]  M_AXI_WSTRB,
    output wire          M_AXI_WLAST,
    output wire          M_AXI_WVALID,
    input wire           M_AXI_WREADY,

    input wire           M_AXI_BVALID,
    output wire          M_AXI_BREADY,

    output wire [31 : 0] M_AXI_ARADDR,
    output wire [7 : 0]  M_AXI_ARLEN,
    output wire [2 : 0]  M_AXI_ARSIZE,
    output wire [1 : 0]  M_AXI_ARBURST,
    output wire [2 : 0]  M_AXI_ARPROT,
    output wire          M_AXI_ARVALID,
    input wire           M_AXI_ARREADY,

    input wire [63 : 0]  M_AXI_RDATA,
    input wire           M_AXI_RLAST,
    input wire           M_AXI_RVALID,
    output wire          M_AXI_RREADY,

    input wire           button
);
   
   
    reg                  write_req;
    wire                 read_req = 1'b0;
    wire                 busy;

    wire [9 : 0]         len = 'd4;
    wire [31 : 0]        address = 32'h4060_0004;
    reg [63 : 0]         wdata;

    reg [3:0]            button_l;
    wire                 button_e;
    reg [9 : 0]          cnt;

    assign button_e = button_l[2] & ~button_l[3];

    always @(posedge M_AXI_ACLK) begin
        button_l  <= {button_l[2:0], button};
        if(~M_AXI_ARESETN) begin
            write_req <= 1'b0;
            cnt <= 'd0;
        end else if(busy) begin
        end else if(write_req) begin
            casez(cnt)
            'd13: wdata <= {24'h0, 8'h65, 32'h0};
            'd12: wdata <= {24'h0, 8'h6C, 32'h0};
            'd11: wdata <= {24'h0, 8'h6C, 32'h0};
            'd10: wdata <= {24'h0, 8'h6F, 32'h0};
            'd9:  wdata <= {24'h0, 8'h2C, 32'h0};
            'd8:  wdata <= {24'h0, 8'h20, 32'h0};
            'd7:  wdata <= {24'h0, 8'h77, 32'h0};
            'd6:  wdata <= {24'h0, 8'h6F, 32'h0};
            'd5:  wdata <= {24'h0, 8'h72, 32'h0};
            'd4:  wdata <= {24'h0, 8'h6C, 32'h0};
            'd3:  wdata <= {24'h0, 8'h64, 32'h0};
            'd2:  wdata <= {24'h0, 8'h0D, 32'h0};
            'd1:  wdata <= {24'h0, 8'h0A, 32'h0};
            'd0:  write_req <= 1'b0;
            endcase
            cnt <= cnt - 1;
        end else if(button_e) begin
            write_req <= 1'b1;
            cnt <= 'd13;
            wdata <= {24'h0, 8'h68, 32'h0};
        end
    end

    budIf budIf (
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
        
        .write_req(write_req),
        .read_req(read_req),
        .busy(busy),
        
        .len(len),
        .address(address),
        .wdata(wdata)
    );

endmodule
module budIf (
    input  logic          M_AXI_ACLK,
    input  logic          M_AXI_ARESETN,

    output logic [31 : 0] M_AXI_AWADDR,
    output logic [7 : 0]  M_AXI_AWLEN,
    output logic [2 : 0]  M_AXI_AWSIZE,
    output logic [1 : 0]  M_AXI_AWBURST,
    output logic [2 : 0]  M_AXI_AWPROT,
    output logic          M_AXI_AWVALID,
    input  logic          M_AXI_AWREADY,

    output logic [63 : 0] M_AXI_WDATA,
    output logic [7 : 0]  M_AXI_WSTRB,
    output logic          M_AXI_WLAST,
    output logic          M_AXI_WVALID,
    input  logic          M_AXI_WREADY,

    input  logic          M_AXI_BVALID,
    output logic          M_AXI_BREADY,

    output logic [31 : 0] M_AXI_ARADDR,
    output logic [7 : 0]  M_AXI_ARLEN,
    output logic [2 : 0]  M_AXI_ARSIZE,
    output logic [1 : 0]  M_AXI_ARBURST,
    output logic [2 : 0]  M_AXI_ARPROT,
    output logic          M_AXI_ARVALID,
    input  logic          M_AXI_ARREADY,

    input  logic [63 : 0] M_AXI_RDATA,
    input  logic          M_AXI_RLAST,
    input  logic          M_AXI_RVALID,
    output logic          M_AXI_RREADY,

    input  logic          write_req,
    input  logic          read_req,
    output logic          busy,

    input  logic [9 : 0]  len, // 1:1, 2:2, 4:4, 6:8, 8n:8(n+1)
    input  logic [31 : 0] address,
    input  logic [63 : 0] wdata
);

    assign M_AXI_AWBURST = 2'b01;
    assign M_AXI_AWPROT  = 3'b000;
    assign M_AXI_ARBURST = 2'b01;
    assign M_AXI_ARPROT  = 3'b000;

    assign M_AXI_BREADY  = 1'b1;

    assign M_AXI_ARADDR = 'b0;
    assign M_AXI_ARLEN = 'b0;
    assign M_AXI_ARSIZE = 'b0;
    //assign M_AXI_ARVALID = 1'b0;
    assign M_AXI_RREADY = 1'b0;

    assign busy = M_AXI_WVALID & ~M_AXI_WREADY |
                  ~(M_AXI_WVALID & ~M_AXI_WLAST) & M_AXI_AWVALID & ~M_AXI_AWREADY |
                  M_AXI_RREADY & ~M_AXI_RVALID;

    logic [7 : 0]         wcnt;

    always_ff @(posedge M_AXI_ACLK) begin
        if(~M_AXI_ARESETN) begin
            M_AXI_ARVALID <= 1'b0;
            M_AXI_AWVALID <= 1'b0;
            M_AXI_WVALID  <= 1'b0;
        end else if(~busy & read_req) begin
        end else if(~busy & write_req) begin
            M_AXI_AWVALID <= 1'b1;
            M_AXI_AWADDR  <= address;
            M_AXI_WVALID  <= 1'b1;
            M_AXI_WDATA   <= wdata;
            casez(len[2:0])
                3'b001: begin M_AXI_AWLEN <= 8'h00;    M_AXI_AWSIZE <= 3'b000; M_AXI_WLAST <= 1'b1; end
                3'b010: begin M_AXI_AWLEN <= 8'h00;    M_AXI_AWSIZE <= 3'b001; M_AXI_WLAST <= 1'b1; end
                3'b100: begin M_AXI_AWLEN <= 8'h00;    M_AXI_AWSIZE <= 3'b010; M_AXI_WLAST <= 1'b1; end
                3'b11?: begin M_AXI_AWLEN <= 8'h00;    M_AXI_AWSIZE <= 3'b011; M_AXI_WLAST <= 1'b1; end
                3'b000: begin M_AXI_AWLEN <= len[9:3]; M_AXI_AWSIZE <= 3'b011; M_AXI_WLAST <= 1'b0; end
            endcase
            wcnt <= len[9:3];
            casez(len[2:0])
                3'b001:  M_AXI_WSTRB <= (1'b1    << address[2:0]);
                3'b010:  M_AXI_WSTRB <= (2'b11   << address[2:0]);
                3'b100:  M_AXI_WSTRB <= (4'b1111 << address[2:0]);
                default: M_AXI_WSTRB <= 8'hff;
            endcase
        end else begin
            if(M_AXI_ARVALID & M_AXI_ARREADY) M_AXI_ARVALID <= 1'b0;
            if(M_AXI_AWVALID & M_AXI_AWREADY) M_AXI_AWVALID <= 1'b0;
            if(M_AXI_WVALID  & M_AXI_WREADY) begin
                M_AXI_WDATA <= wdata;
                if(M_AXI_WLAST)       M_AXI_WVALID <= 1'b0;
                else if(wcnt == 8'b1) M_AXI_WLAST <= 1'b1;
                else                  wcnt <= wcnt - 1;
            end
        end
    end

endmodule
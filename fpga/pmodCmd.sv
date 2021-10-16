module pmodCmd (
    input  logic             clk,
    input  logic             reset,
    input  logic             pck,
    input  logic             pwrite,
    input  logic [1:0]       pwd,
    output logic [1:0]       prd,
    output logic             pwait,

    output logic             write_req,
    output logic             read_req,
    input  logic             busy,

    output logic [9:0]       len,
    output logic [31:0]      address,
    output logic [63:0]      wdata
);

    assign pwait = 1'b0;
    assign prd = 2'b00;

    logic       penable;
    logic [3:0] pck_l;
    always_ff @(posedge clk) begin
        pck_l <= {pck_l[2:0], pck};
        if(reset) penable <= 1'b0;
`ifdef SIM
        else      penable <= ({pck_l[0], pck} == 2'b10);      // SIM 用
`else
        else      penable <= ({pck_l[3:0], pck} == 5'b10000); // 気持ちジッタ対策
`endif
    end

    enum { IDLE, WLEN, WADDRESS, WDATA, RLEN } state; // TEMP TEMP READ に対応してない
    logic [11:0] cnt;
    always_ff @(posedge clk) begin
        if(reset) begin
            state = IDLE;
            write_req <= 1'b0;
            read_req <= 1'b0;
            wdata <= 64'h0;
        end else if (penable) begin
            casez(state)
                IDLE: begin
                    if(pwrite) state <= WLEN; else state <= RLEN;
                    len[0 +: 2] <= pwd;  // LEN の最初の 1サイクル分
                    cnt <= 1;            // LEN の最初の 1サイクル分
                end
                WLEN: begin
                    len[cnt*2 +: 2] <= pwd;
                    if(cnt == 4) begin
                        state <= WADDRESS;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                WADDRESS: begin
                    address[cnt*2 +: 2] <= pwd;
                    if(cnt == 15) begin
                        state <= WDATA;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                WDATA: begin   // TEMP TEMP 32bit しか対応できない // FIFO に入れたい
                    wdata[address[2:0]*8+cnt*2 +: 2] <= pwd;
                    if(cnt == 15) begin
                        write_req <= 1'b1;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
            endcase
        end else begin
            if(write_req | read_req) begin
                state <= IDLE;
                write_req <= 1'b0;
                read_req <= 1'b0;
            end
        end
    end

//                        casez(len[2:0])
//                            3'b001: cnt <= 1 * 4 - 1;
//                            3'b010: cnt <= 2 * 4 - 1;
//                            3'b100: cnt <= 4 * 4 - 1;
//                            3'b11?: cnt <= 8 * 4 - 1;
//                            3'b000: cnt <= (len[9:3] + 1) * 4 - 1;
//                        endcase

endmodule
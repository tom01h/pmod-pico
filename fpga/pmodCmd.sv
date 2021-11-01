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
    output logic [63:0]      wdata,
    input  logic [63:0]      rdata,
    input  logic             rlast
);

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

    enum { IDLE, WLEN, WADDRESS, WDATA, RLEN, RADDRESS, RDATA, RFIN } state;
    logic [11:0] cnt;
    logic [11:0] datalen;
    always_ff @(posedge clk) begin
        if(reset) begin
            state = IDLE;
            write_req <= 1'b0;
            read_req <= 1'b0;
            wdata <= 64'h0;
            pwait <= 1'b0;
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
                WDATA: begin   // TEMP TEMP 64bit までしか対応できない // FIFO に入れたい
                    wdata[address[2:0]*8+cnt*2 +: 2] <= pwd;
                    if(cnt == datalen) begin
                        write_req <= 1'b1;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                RLEN: begin
                    len[cnt*2 +: 2] <= pwd;
                    if(cnt == 4) begin
                        state <= RADDRESS;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                RADDRESS: begin
                    address[cnt*2 +: 2] <= pwd;
                    if(cnt == 15) begin
                        pwait <= 1'b1;
                        read_req <= 1'b1;
                        state <= RDATA;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                RDATA: begin   // TEMP TEMP 64bit までしか対応できない // FIFO に入れたい
                    read_req <= 1'b0;
                    if(busy) begin
                        pwait <= 1'b1;
                    end else begin
                        pwait <= 1'b0;
                        prd <= rdata[address[2:0]*8+cnt*2 +: 2];
                        if(cnt == datalen) begin
                            cnt <= 0;
                            state <= RFIN;
                        end else begin
                            cnt <= cnt + 1;
                        end
                    end    
                end
                RFIN: begin   // firmware で最後の1クロック止めるの大変なので
                    state <= IDLE;
                end    
            endcase
        end else begin
            if(write_req) begin
                state <= IDLE;
                write_req <= 1'b0;
            end
            if(read_req) begin
                read_req <= 1'b0;
            end
        end
    end

    always_comb begin
        casez(len[2:0])
            3'b001: datalen <= 1 * 4 - 1;
            3'b010: datalen <= 2 * 4 - 1;
            3'b100: datalen <= 4 * 4 - 1;
            3'b11?: datalen <= 8 * 4 - 1;
            3'b000: datalen <= (len + 8) * 4 - 1;
        endcase
    end

endmodule
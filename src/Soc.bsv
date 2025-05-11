import GetPut :: *;
import Vector :: *;

import AXI4_Master :: *;
import AXI4_Slave :: *;
import AXI4_Types :: *;

interface Soc;
  (* prefix = "master0" *)
  interface AXI4_Master_Rd_Fab#(32, 64, 3, 5) rdMaster0;

  (* prefix = "master0" *)
  interface AXI4_Master_Wr_Fab#(32, 64, 3, 5) wrMaster0;

  (* prefix = "slave0" *)
  interface AXI4_Slave_Rd_Fab#(32, 32, 12, 0) rdSlave0;

  (* prefix = "slave0" *)
  interface AXI4_Slave_Wr_Fab#(32, 32, 12, 0) wrSlave0;

  (* prefix = "slave1" *)
  interface AXI4_Slave_Rd_Fab#(32, 32, 12, 0) rdSlave1;

  (* prefix = "slave1" *)
  interface AXI4_Slave_Wr_Fab#(32, 32, 12, 0) wrSlave1;

  (* prefix = "leds", always_ready, always_enabled *)
  method Bit#(8) leds;
endinterface

typedef enum {Idle, Read, Write} State deriving(Bits, FShow, Eq);

module mkSoc(Soc);
  // ACP port of the CPU (cache coherent DMA interface)
  AXI4_Master_Rd#(32, 64, 3, 5) rdMaster <- mkAXI4_Master_Rd(2, 2, False);
  AXI4_Master_Wr#(32, 64, 3, 5) wrMaster <- mkAXI4_Master_Wr(2, 2, 2, False);

  // Slave interface to receive commands from the host CPU
  Vector#(2, AXI4_Slave_Rd#(32, 32, 12, 0)) rdSlave <-
    replicateM(mkAXI4_Slave_Rd(2, 2));

  Vector#(2, AXI4_Slave_Wr#(32, 32, 12, 0)) wrSlave <-
    replicateM(mkAXI4_Slave_Wr(2, 2, 2));

  Reg#(Maybe#(Bit#(32))) addr <- mkReg(Invalid);
  Reg#(Bit#(32)) startAddr <- mkReg(?);
  Reg#(Bit#(32)) size <- mkReg(?);

  Reg#(Bit#(32)) counter <- mkReg(0);

  rule count;
    counter <= counter + 1;
  endrule

  rule writeRequest if (addr matches tagged Valid .a);
    addr <= a + 4 == startAddr + size ? Invalid : Valid(a + 4);

    axi4_write_addr(wrMaster, a, 0);
    axi4_write_data(wrMaster, 64'haaaaaaaa55555555, -1, True);
  endrule

  rule writeResponse;
    let _ <- axi4_write_response(wrMaster);
  endrule

  Reg#(AXI4_Write_Rq_Addr#(32, 12, 0)) wrRequest <- mkReg(?);
  Reg#(AXI4_Read_Rq#(32, 12, 0)) rdRequest <- mkReg(?);
  Reg#(UInt#(8)) length <- mkReg(?);
  Reg#(Bit#(32)) receiveAddr <- mkReg(?);

  Reg#(State) state <- mkReg(Idle);

  for (Integer i=0; i < 2; i = i + 1) begin
    rule receiveWriteAddr if (state == Idle);
      let req <- wrSlave[i].request_addr.get;
      length <= req.burst_length;
      receiveAddr <= req.addr;
      wrRequest <= req;
      state <= Write;
    endrule

    rule receiveData if (state == Write);
      let req <- wrSlave[i].request_data.get;

      // Compute mask in case of an unaligned access
      Bit#(4) mask = case (receiveAddr[2:1]) matches
        2'b00 : 4'b1111 & req.strb;
        2'b01 : 4'b1110 & req.strb;
        2'b10 : 4'b1100 & req.strb;
        2'b11 : 4'b1000 & req.strb;
      endcase;

      state <= length == 0 ? Idle : Write;
      receiveAddr <= (receiveAddr & ~3) + 4;
      length <= length - 1;

      if (req.last)
        wrSlave[i].response.put(AXI4_Write_Rs{
          user: wrRequest.user,
          id: wrRequest.id,
          resp: OKAY
        });

      if (receiveAddr == 32'h40000004 && mask == 4'b1111) begin
        addr <= Valid(req.data);
      end

      if (receiveAddr == 32'h40000004 && mask == 4'b1111) begin
        size <= req.data;
      end
    endrule
  end

  Reg#(Bit#(32)) numRdReq <- mkReg(0);

  for (Integer i=0; i < 2; i = i + 1) begin
    rule receiveReadRequest if (state == Idle);
      let req <- rdSlave[i].request.get;
      length <= req.burst_length;
      receiveAddr <= req.addr;
      rdRequest <= req;
      state <= Read;

      numRdReq <= numRdReq + 1;
    endrule

    rule respondRead if (state == Read);
      rdSlave[i].response.put(AXI4_Read_Rs{
        user: rdRequest.user,
        data: numRdReq, // 32'h12345678,
        id: rdRequest.id,
        last: length == 0,
        resp: OKAY
      });

      receiveAddr <= (receiveAddr & ~3) + 4;
      state <= length == 0 ? Idle : Read;
      length <= length - 1;
    endrule
  end

  interface rdMaster0 = rdMaster.fab;
  interface wrMaster0 = wrMaster.fab;
  interface rdSlave0 = rdSlave[0].fab;
  interface wrSlave0 = wrSlave[0].fab;
  interface rdSlave1 = rdSlave[1].fab;
  interface wrSlave1 = wrSlave[1].fab;
  method leds = counter[31:24];
endmodule



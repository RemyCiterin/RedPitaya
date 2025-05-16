import BuildVector :: *;
import GetPut :: *;
import Vector :: *;

import AXI3_Master :: *;
import AXI3_Slave :: *;
import AXI3_Types :: *;
import Packet :: *;

interface Soc;
  (* prefix = "master0" *)
  interface AXI3_Master_Rd_Fab#(32, 64, 3) rdMaster0;

  (* prefix = "master0" *)
  interface AXI3_Master_Wr_Fab#(32, 64, 3) wrMaster0;

  (* prefix = "slave0" *)
  interface AXI3_Slave_Rd_Fab#(32, 32, 12) rdSlave0;

  (* prefix = "slave0" *)
  interface AXI3_Slave_Wr_Fab#(32, 32, 12) wrSlave0;

  (* prefix = "slave1" *)
  interface AXI3_Slave_Rd_Fab#(32, 32, 12) rdSlave1;

  (* prefix = "slave1" *)
  interface AXI3_Slave_Wr_Fab#(32, 32, 12) wrSlave1;

  (* prefix = "leds", always_ready, always_enabled *)
  method Bit#(8) leds;

  (* prefix = "", always_ready, always_enabled *)
  method Action readAdc(
    (* port="adc_data0" *)Bit#(16) data0,
    (* port="adc_data1" *)Bit#(16) data1);
endinterface

typedef enum {Idle, Read, Write} State deriving(Bits, FShow, Eq);

module mkSoc(Soc);
  // ACP port of the CPU (cache coherent DMA interface)
  AXI3_Master_Rd#(32, 64, 3) rdMaster <- mkAXI3_Master_Rd(2, 2, False);

  let sender <- mkPacketSender;

  // Slave interface to receive commands from the host CPU
  Vector#(2, AXI3_Slave_Rd#(32, 32, 12)) rdSlave <-
    replicateM(mkAXI3_Slave_Rd(2, 2));

  Vector#(2, AXI3_Slave_Wr#(32, 32, 12)) wrSlave <-
    replicateM(mkAXI3_Slave_Wr(2, 2, 2));

  Reg#(Bit#(32)) counter <- mkReg(0);

  Wire#(Bit#(16)) inputData <- mkWire;

  rule sendData;
    sender.push(inputData);
  endrule

  rule count;
    counter <= counter + 1;
  endrule

  Reg#(AXI3_Write_Rq_Addr#(32, 12)) wrRequest <- mkReg(?);
  Reg#(AXI3_Read_Rq#(32, 12)) rdRequest <- mkReg(?);
  Reg#(UInt#(4)) length <- mkReg(?);
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
      Bit#(4) mask = case (receiveAddr[1:0]) matches
        2'b00 : 4'b1111 & req.strb;
        2'b01 : 4'b1110 & req.strb;
        2'b10 : 4'b1100 & req.strb;
        2'b11 : 4'b1000 & req.strb;
      endcase;

      state <= length == 0 ? Idle : Write;
      receiveAddr <= (receiveAddr & ~3) + 4;
      length <= length - 1;

      if (req.last)
        wrSlave[i].response.put(AXI3_Write_Rs{
          id: wrRequest.id,
          resp: OKAY
        });

      if (receiveAddr == 32'h40000000 && mask == 4'b1111) begin
        sender.setAddr(req.data);
      end

      if (receiveAddr == 32'h40000004 && mask == 4'b1111) begin
        sender.setSize(req.data);
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
      rdSlave[i].response.put(AXI3_Read_Rs{
        data: receiveAddr == 32'h40000000 ? sender.numBlocked : receiveAddr,
        id: rdRequest.id,
        last: length == 0,
        resp: OKAY
      });

      receiveAddr <= (receiveAddr & ~3) + 4;
      state <= length == 0 ? Idle : Read;
      length <= length - 1;
    endrule
  end

  interface wrMaster0 = sender.fab;
  interface rdMaster0 = rdMaster.fab;
  interface rdSlave0 = rdSlave[0].fab;
  interface wrSlave0 = wrSlave[0].fab;
  interface rdSlave1 = rdSlave[1].fab;
  interface wrSlave1 = wrSlave[1].fab;
  method leds = counter[31:24];
  method Action readAdc(Bit#(16) d0, Bit#(16) d1);
    inputData <= d0;
  endmethod
endmodule

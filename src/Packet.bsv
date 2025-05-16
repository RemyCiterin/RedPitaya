import BuildVector :: *;
import GetPut :: *;
import Vector :: *;

import AXI3_Master :: *;
import AXI3_Slave :: *;
import AXI3_Types :: *;

import Ehr :: *;
import Fifo :: *;

module mkPacketBuilder(Tuple2#(FifoI#(Bit#(16)), FifoO#(Bit#(64))));
  Fifo#(256, Bit#(16)) inQ <- mkFifo;
  Fifo#(2, Bit#(64)) outQ <- mkFifo;

  Reg#(Bit#(64)) data <- mkReg(0);
  Reg#(Bit#(4)) mask <- mkReg(0);

  rule step;
    Bit#(4) m = {1'b1, truncateLSB(mask)};
    Bit#(64) d = {inQ.first, truncateLSB(data)};

    inQ.deq;
    data <= d;
    mask <= m == 4'b1111 ? 0 : m;
    if (m == 4'b1111) outQ.enq(d);
  endrule

  return tuple2(toFifoI(inQ),toFifoO(outQ));
endmodule

// Receive 16 bit data and send them by blocks
interface PacketSender;

  interface AXI3_Master_Wr_Fab#(32, 64, 3) fab;

  // Send a new item
  method Action push(Bit#(16) data);

  // return the number of packets blocked by bus contention
  method Bit#(32) numBlocked;

  // Return the base address of the buffer
  method Action setAddr(Bit#(32) addr);

  // Set the size of the buffer in bytes
  method Action setSize(Bit#(32) size);
endinterface

module mkPacketSender(PacketSender);
  // ACP port of the CPU (accelerator coherent interface)
  AXI3_Master_Wr#(32, 64, 3) master <- mkAXI3_Master_Wr(2, 2, 2, False);

  Reg#(Maybe#(UInt#(4))) length <- mkReg(Invalid);

  Reg#(Bit#(32)) baseAddr <- mkReg(?);
  Reg#(Maybe#(Bit#(32))) addr <- mkReg(Invalid);
  Reg#(Bit#(32)) size <- mkReg(0);

  let builder <- mkPacketBuilder;

  function Maybe#(Bit#(32)) updateAddr(Bit#(32) a) =
    a+8 >= baseAddr+size ? Invalid : Valid(a+8);

  rule sendAddr if (addr matches tagged Valid .a &&& length == Invalid);
    UInt#(32) rest = unpack(baseAddr + size - a - 8) / 8;
    UInt#(4) len = rest < 16 ? truncate(rest) : 15;

    master.request_addr.put(AXI3_Write_Rq_Addr{
      id: 0,
      addr: a,
      burst_length: len,
      burst_size: bitsToBurstSizeAXI3(64),
      burst_type: INCR,
      lock: NORMAL,
      cache: WRITE_BACK_WRITE_ALLOCATE,
      prot: UNPRIV_SECURE_DATA
    });

    length <= Valid(len);
  endrule

  Wire#(Bool) send <- mkDWire(False);
  Reg#(Bit#(32)) blocked <- mkReg(0);

  rule testBlocked if (addr matches tagged Valid .a &&& !send && !builder.fst.canEnq);
    blocked <= blocked + 1;
  endrule

  rule sendData if (addr matches tagged Valid .a &&& length matches tagged Valid .len);
    master.request_data.put(AXI3_Write_Rq_Data{
      id: 0,
      data: builder.snd.first,
      strb: 8'b11111111,
      last: len == 0
    });

    send <= True;

    builder.snd.deq;

    length <= len == 0 ? Invalid : Valid(len-1);
    addr <= updateAddr(a);
  endrule

  rule receiveResponse;
    let _ <- axi3_write_response(master);
  endrule

  method Action push(Bit#(16) data);
    builder.fst.enq(data);
  endmethod

  method Action setSize(Bit#(32) sz);
    size <= sz;
  endmethod

  method Action setAddr(Bit#(32) a) if (addr == Invalid);
    addr <= Valid(a);
    baseAddr <= a;
  endmethod

  interface fab = master.fab;

  method numBlocked = blocked;
endmodule

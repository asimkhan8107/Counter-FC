///////////////////// Transcation class
class transaction;
  rand bit [7:0] loadin;
  bit rst;
  bit load;
  bit up;
  bit [7:0] y;
endclass

///////////////////// generation class
class generator;
  transaction t;
  mailbox mbx;
  event done;
  integer i;
  
  function new(mailbox mbx);
  	this.mbx = mbx;
  endfunction
  
  task run();
    t = new();
    for(i = 0; i < 200; i++)
      begin
        t.randomize;
        mbx.put(t);
        $display("[GEN]: Data send to driver");
        @done;
      end
  endtask
endclass

///////////////////// interface
interface counter_intf();
  logic rst, clk, load, up;
  logic [7:0] loadin;
  logic [7:0] y;
endinterface

///////////////////// driver
class driver;
  mailbox mbx;
  transaction t;
  event done;
  
  virtual counter_intf vif;
  
  function new(mailbox mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    t = new();
    forever begin
      mbx.get(t);
      vif.loadin = t.loadin;
      $display("[DRV] : Trigger Interface");
      @(posedge vif.clk);
      	->done;
    end
  endtask
endclass

///////////////////// monitor
class monitor;
  mailbox mbx;
  transaction t;
  
  virtual counter_intf vif;
  
  //Functional Coverage
  covergroup c;
    option.per_instance = 1;
    
    //// loadin(input) coverpoint
    coverpoint t.loadin {
      bins lower = {[0:84]};
      bins mid = {[85:169]};
      bins high = {[170:255]};
    }
    /// rst coverpoint
    coverpoint t.rst {
      bins rst_low = {0};
      bins rst_high = {1};
    }
    //// load coverpoint
    coverpoint t.load {
      bins load_low = {0};
      bins load_high = {1};
    }
    /////up coverpoint
    coverpoint t.up {
      bins up_low = {0};
      bins up_high = {1};
    }
    ////// output coverpoint
    coverpoint t.y {
      bins lower = {[0:84]};
      bins mid = {[85:169]};
      bins high = {[170:255]};
    }
    // cross coverage
    cross_load_loadin: cross t.load, t.loadin {
      ignore_bins unused_load = binsof(t.load) intersect {0};
    }
    cross_rst_y: cross t.rst, t.y {
      ignore_bins unused_rst = binsof(t.rst) intersect {1};
    }
  endgroup
  
  function new(mailbox mbx);
    this.mbx = mbx;
    c = new();
  endfunction
  
  task run();
    t = new();   // allocating memory for transaction object
    forever begin
      @(posedge vif.clk);
      t.loadin = vif.loadin;
      t.y = vif.y;
      t.rst = vif.rst;
      t.up = vif.up;
      t.load = vif.load;
      c.sample();
      mbx.put(t);  	// puting transaction object t into mailbox
      $display("[MON] : Data send to scoreborad");
    //  @(posedge vif.clk);
    end
  endtask
endclass

//////////// Scoreboard
class scoreboard;
  mailbox mbx;
  transaction t;
//   bit [7:0] temp;
  
  function new(mailbox mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    t = new();
    forever begin
      mbx.get(t);   // geting transaction object t from mailbox
      $display("[SCB] : Data received from monitor");	
    end
  endtask
endclass

/////////////// Environment
class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  mailbox gdmbx; // generator to driver mailbox
  mailbox msmbx; // monitor to scoreboard mailbox
  virtual counter_intf vif;
  
  event gddone;
  
  function new(mailbox gdmbx, mailbox msmbx);
    this.gdmbx = gdmbx;
    this.msmbx = msmbx;
    
    gen = new(gdmbx);
    drv = new(gdmbx);
    mon = new(msmbx);
    sco = new(msmbx);
  endfunction
  
  task run();
    gen.done = gddone;
    drv.done = gddone;
    
    // using driver and monitor virtually 
    drv.vif = vif;
    mon.vif = vif;
    
    // run all classes con-curently
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
endclass

module tb_top();
  environment env;
  mailbox gdmbx;
  mailbox msmbx;
  counter_intf vif();
  
  // Design Positional instantiation
  counter dut(vif.clk, vif.rst, vif.up, vif.load, vif.loadin, vif.y);
  
  always #5 vif.clk = ~vif.clk;
  
  initial begin
    vif.clk = 0;
    vif.rst = 1;
    #50;
    vif.rst = 0;
  end
  
  initial begin
    #60;
    repeat(20)begin
      vif.load = 1;
      #10;
      vif.load = 0;
      #100;
    end
  end
  
  initial begin
    #60;
    repeat(20)begin
      vif.up = 1;
      #70;
      vif.up = 0;
      #70;
    end
  end
  
  initial begin
    gdmbx = new();
    msmbx = new();
    env = new(gdmbx,msmbx);
    env.vif = vif;
    env.run();
    #2000;
    $finish;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
endmodule

    

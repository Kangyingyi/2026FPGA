`timescale 1ns/1ps
module tb_octave_engines;
    reg clk=0, rst_n=0, sample_tick=0;
    reg [1:0] octave_sel=1;
    wire signed [15:0] glide_audio, vibrato_audio, pluck_audio;
    always #5 clk=~clk;

    glide_dds glide (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(8'h01), .octave_sel(octave_sel), .sample(glide_audio)
    );
    vibrato_dds vibrato (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(8'h01), .octave_sel(octave_sel), .sample(vibrato_audio)
    );
    polyphonic_pluck pluck (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(8'h01), .octave_sel(octave_sel),
        .pluck_trigger(1'b0), .sample(pluck_audio)
    );

    task check_steps;
      input [1:0] octave;
      begin
        octave_sel=octave; #1;
        if (pluck.v_0.phase_step !== ((octave==0) ? (32'd23013218>>1) :
                                      (octave==2) ? (32'd23013218<<1) : 32'd23013218))
            $fatal(1,"pluck octave step mismatch: %d",octave);
        if (glide.pitch[0].octave_increment !== ((octave==0) ? (glide.pitch[0].increment>>1) :
                                                 (octave==2) ? (glide.pitch[0].increment<<1) : glide.pitch[0].increment))
            $fatal(1,"glide octave step mismatch: %d",octave);
        if (vibrato.pitch[0].octave_increment !== ((octave==0) ? (vibrato.pitch[0].increment>>1) :
                                                   (octave==2) ? (vibrato.pitch[0].increment<<1) : vibrato.pitch[0].increment))
            $fatal(1,"vibrato octave step mismatch: %d",octave);
      end
    endtask
    initial begin
        #25; rst_n=1;
        check_steps(1);
        check_steps(0);
        check_steps(2);
        $display("OCTAVE_ENGINES_PASS"); $finish;
    end
endmodule

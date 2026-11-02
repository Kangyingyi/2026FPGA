`timescale 1ns/1ps

// End-to-end audio demo plus fast-tick DDS checks (no 6.5M-cycle wait).
module tb_glide_audio;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [7:0] raw_keys = 8'h00;
    reg [7:0] direct_keys = 8'h00;
    reg direct_tick = 1'b0;
    wire bclk, lrck, din, pa_en;
    wire signed [15:0] direct_sample_out;
    localparam [31:0] STEP_C4 = 32'd23013218;
    localparam [31:0] STEP_C5 = 32'd46025557;
    integer n;
    integer sys_cycles = 0, last_tick = -1, audio_ticks = 0;
    reg [31:0] before0, before7;
    reg bclk_seen = 1'b0, lrck_seen = 1'b0;
    reg old_bclk = 1'b0, old_lrck = 1'b1;
    reg [15:0] decoded_left;
    integer serial_nonzero = 0;
    integer bit_index;

    always #5 clk = ~clk;

    glide_dds synth (
        .clk(clk), .rst_n(rst_n), .sample_tick(direct_tick),
        .key_state(direct_keys), .sample(direct_sample_out)
    );
    glide_top #(.DEBOUNCE_CYCLES(4)) top (
        .sys_clk(clk), .rst_n(rst_n), .key_in(raw_keys),
        .I2S_BCLK(bclk), .I2S_LRCK(lrck), .I2S_DIN(din), .PA_EN(pa_en)
    );

    task fast_tick;
        begin
            @(negedge clk); direct_tick = 1'b1;
            @(negedge clk); direct_tick = 1'b0;
            #1;
        end
    endtask

    task audio_tick;
        begin
            @(posedge top.sample_tick);
            @(posedge clk);
            #1;
        end
    endtask

    task receive_left;
        begin
            @(negedge lrck);
            @(posedge bclk); // Philips I2S one-bit delay
            decoded_left = 16'h0000;
            for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1) begin
                @(posedge bclk);
                #1;
                decoded_left = {decoded_left[14:0], din};
            end
            if (decoded_left !== top.tx.left_hold)
                $fatal(1, "top I2S serial output differs from generated PCM");
            if (decoded_left != 16'h0000)
                serial_nonzero = serial_nonzero + 1;
        end
    endtask

    always @(posedge clk) begin
        if (rst_n) begin
            sys_cycles = sys_cycles + 1;
            if (bclk != old_bclk) bclk_seen = 1'b1;
            if (lrck != old_lrck) lrck_seen = 1'b1;
            old_bclk = bclk;
            old_lrck = lrck;
            if (top.sample_tick) begin
                if (last_tick >= 0 && sys_cycles - last_tick != 1024)
                    $fatal(1, "I2S sample interval is not 1024 sys clocks");
                last_tick = sys_cycles;
                audio_ticks = audio_ticks + 1;
            end
        end
    end

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        fast_tick();
        if (direct_sample_out !== 16'sd0 || pa_en !== 1'b0)
            $fatal(1, "silence and PA_EN polarity wrong");

        direct_keys = 8'h01;
        fast_tick();
        before0 = synth.phase[0];
        fast_tick();
        if (synth.phase[0] - before0 >= STEP_C4)
            $fatal(1, "C4 did not begin below its target frequency");
        for (n = 0; n < 6500; n = n + 1) fast_tick();
        before0 = synth.phase[0];
        fast_tick();
        if (synth.phase[0] - before0 !== STEP_C4)
            $fatal(1, "C4 glide did not finish at exact target step");

        direct_keys = 8'h81;
        fast_tick();
        before0 = synth.phase[0];
        before7 = synth.phase[7];
        fast_tick();
        if (synth.phase[0] - before0 !== STEP_C4 ||
            synth.phase[7] - before7 >= STEP_C5 ||
            synth.phase[7] - before7 <= 32'd40000000)
            $fatal(1, "new C5 must glide without restarting held C4");
        direct_keys = 8'h80;
        fast_tick();
        if (synth.phase[0] !== 32'd0 || synth.phase[7] === 32'd0)
            $fatal(1, "voices must release independently");
        direct_keys = 8'h00;
        fast_tick();
        if (direct_sample_out !== 16'sd0)
            $fatal(1, "all released keys must be silent");
        direct_keys = 8'h01;
        fast_tick();
        if (synth.pitch[0].voice_pitch.offset_q15 !== -16'sd3577)
            $fatal(1, "re-touch must start a new glide");

        raw_keys = 8'h81;
        repeat (10) @(negedge clk);
        if (top.key_state !== 8'h81)
            $fatal(1, "OUT1/OUT8 must map to key bits 0/7");
        repeat (12) audio_tick();
        if (top.audio_sample === 16'sd0 ||
            top.tx.left_hold !== top.tx.right_hold ||
            !bclk_seen || !lrck_seen || audio_ticks < 2)
            $fatal(1, "live I2S stereo audio path is missing");
        for (n = 0; n < 8; n = n + 1) receive_left();
        if (serial_nonzero == 0)
            $fatal(1, "top I2S DIN remained silent while keys were touched");
        raw_keys = 8'h00;
        repeat (10) @(negedge clk);
        audio_tick();
        if (top.audio_sample !== 16'sd0)
            $fatal(1, "top audio must become silent after release");

        $display("TB_GLIDE_AUDIO_PASS");
        $finish;
    end
endmodule

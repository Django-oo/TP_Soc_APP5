library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity Sensor_avalon_interface is
    port (
        clock      : in  std_logic;
        reset_n    : in  std_logic;

        address    : in  std_logic_vector(1 downto 0);
        chipselect : in  std_logic;
        write      : in  std_logic;
        read       : in  std_logic;
        byteenable : in  std_logic_vector(3 downto 0);
        writedata  : in  std_logic_vector(31 downto 0);
        readdata   : out std_logic_vector(31 downto 0);

        ADC_CONVST : out std_logic;
        ADC_SCK    : out std_logic;
        ADC_SDI    : out std_logic;
        ADC_SDO    : in  std_logic
    );
end entity Sensor_avalon_interface;

architecture rtl of Sensor_avalon_interface is
    signal sensor_pll_clocks : std_logic_vector(5 downto 0);
    signal sensor_clock      : std_logic;
    signal pll_reset         : std_logic;
    signal pll_locked        : std_logic;
    signal pll_locked_meta   : std_logic := '0';
    signal pll_locked_sync   : std_logic := '0';
    signal core_reset_n      : std_logic;

    signal capture_toggle          : std_logic := '0';
    signal capture_toggle_meta     : std_logic := '0';
    signal capture_toggle_sync     : std_logic := '0';
    signal capture_toggle_sync_d   : std_logic := '0';
    signal capture_pulse_sensor    : std_logic := '0';

    signal threshold     : std_logic_vector(7 downto 0) := x"80";
    signal core_ready    : std_logic;
    signal data0         : std_logic_vector(7 downto 0);
    signal data1         : std_logic_vector(7 downto 0);
    signal data2         : std_logic_vector(7 downto 0);
    signal data3         : std_logic_vector(7 downto 0);
    signal data4         : std_logic_vector(7 downto 0);
    signal data5         : std_logic_vector(7 downto 0);
    signal data6         : std_logic_vector(7 downto 0);
    signal sensors       : std_logic_vector(6 downto 0);
    signal core_ready_d  : std_logic := '0';

    signal data0_sensor   : std_logic_vector(7 downto 0) := (others => '0');
    signal data1_sensor   : std_logic_vector(7 downto 0) := (others => '0');
    signal data2_sensor   : std_logic_vector(7 downto 0) := (others => '0');
    signal data3_sensor   : std_logic_vector(7 downto 0) := (others => '0');
    signal data4_sensor   : std_logic_vector(7 downto 0) := (others => '0');
    signal data5_sensor   : std_logic_vector(7 downto 0) := (others => '0');
    signal data6_sensor   : std_logic_vector(7 downto 0) := (others => '0');
    signal sensors_sensor : std_logic_vector(6 downto 0) := (others => '0');
    signal data_toggle_sensor : std_logic := '0';

    signal data_toggle_meta   : std_logic := '0';
    signal data_toggle_sync   : std_logic := '0';
    signal data_toggle_sync_d : std_logic := '0';

    signal ready_latched   : std_logic := '0';
    signal data0_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal data1_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal data2_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal data3_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal data4_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal data5_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal data6_latched   : std_logic_vector(7 downto 0) := (others => '0');
    signal sensors_latched : std_logic_vector(6 downto 0) := (others => '0');
begin
    sensor_clock <= sensor_pll_clocks(0);
    pll_reset    <= not reset_n;
    core_reset_n <= reset_n and pll_locked;

    sensor_pll : altpll
        generic map (
            clk0_divide_by         => 5,
            clk0_duty_cycle        => 50,
            clk0_multiply_by       => 4,
            clk0_phase_shift       => "0",
            compensate_clock       => "CLK0",
            inclk0_input_frequency => 20000,
            intended_device_family => "Cyclone IV",
            lpm_type               => "altpll",
            operation_mode         => "NORMAL",
            pll_type               => "AUTO",
            port_activeclock       => "PORT_UNUSED",
            port_areset            => "PORT_USED",
            port_clkbad0           => "PORT_UNUSED",
            port_clkbad1           => "PORT_UNUSED",
            port_clkloss           => "PORT_UNUSED",
            port_clkswitch         => "PORT_UNUSED",
            port_fbin              => "PORT_UNUSED",
            port_inclk0            => "PORT_USED",
            port_inclk1            => "PORT_UNUSED",
            port_locked            => "PORT_USED",
            port_pfdena            => "PORT_UNUSED",
            port_pllena            => "PORT_UNUSED",
            port_clk0              => "PORT_USED",
            port_clk1              => "PORT_UNUSED",
            port_clk2              => "PORT_UNUSED",
            port_clk3              => "PORT_UNUSED",
            port_clk4              => "PORT_UNUSED",
            port_clk5              => "PORT_UNUSED",
            width_clock            => 6
        )
        port map (
            inclk       => (1 => '0', 0 => clock),
            clk         => sensor_pll_clocks,
            locked      => pll_locked,
            activeclock => open,
            areset      => pll_reset,
            clkbad      => open,
            clkena      => (others => '1'),
            clkloss     => open,
            clkswitch   => '0',
            enable0     => open,
            enable1     => open,
            extclk      => open,
            extclkena   => (others => '1'),
            fbin        => '1',
            pfdena      => '1',
            pllena      => '1',
            scanaclr    => '0',
            scanclk     => '0',
            scandata    => '0',
            scandataout => open,
            scandone    => open,
            scanread    => '0',
            scanwrite   => '0',
            sclkout0    => open,
            sclkout1    => open
        );

    avalon_write_process : process(clock, reset_n)
    begin
        if reset_n = '0' then
            capture_toggle    <= '0';
            threshold         <= x"80";
            ready_latched     <= '0';
            data_toggle_meta  <= '0';
            data_toggle_sync  <= '0';
            data_toggle_sync_d <= '0';
            pll_locked_meta   <= '0';
            pll_locked_sync   <= '0';
            data0_latched     <= (others => '0');
            data1_latched     <= (others => '0');
            data2_latched     <= (others => '0');
            data3_latched     <= (others => '0');
            data4_latched     <= (others => '0');
            data5_latched     <= (others => '0');
            data6_latched     <= (others => '0');
            sensors_latched   <= (others => '0');
        elsif rising_edge(clock) then
            pll_locked_meta    <= pll_locked;
            pll_locked_sync    <= pll_locked_meta;
            data_toggle_meta   <= data_toggle_sensor;
            data_toggle_sync   <= data_toggle_meta;
            data_toggle_sync_d <= data_toggle_sync;

            if data_toggle_sync /= data_toggle_sync_d then
                ready_latched   <= '1';
                data0_latched   <= data0_sensor;
                data1_latched   <= data1_sensor;
                data2_latched   <= data2_sensor;
                data3_latched   <= data3_sensor;
                data4_latched   <= data4_sensor;
                data5_latched   <= data5_sensor;
                data6_latched   <= data6_sensor;
                sensors_latched <= sensors_sensor;
            end if;

            if chipselect = '1' and write = '1' then
                case address is
                    when "00" =>
                        if byteenable(0) = '1' then
                            if writedata(0) = '1' then
                                capture_toggle <= not capture_toggle;
                                ready_latched  <= '0';
                            end if;

                            if writedata(1) = '1' then
                                ready_latched <= '0';
                            end if;
                        end if;

                    when "01" =>
                        if byteenable(0) = '1' then
                            threshold <= writedata(7 downto 0);
                        end if;

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process avalon_write_process;

    sensor_clock_process : process(sensor_clock, core_reset_n)
    begin
        if core_reset_n = '0' then
            capture_toggle_meta   <= '0';
            capture_toggle_sync   <= '0';
            capture_toggle_sync_d <= '0';
            capture_pulse_sensor  <= '0';
            core_ready_d          <= '0';
            data_toggle_sensor    <= '0';
            data0_sensor          <= (others => '0');
            data1_sensor          <= (others => '0');
            data2_sensor          <= (others => '0');
            data3_sensor          <= (others => '0');
            data4_sensor          <= (others => '0');
            data5_sensor          <= (others => '0');
            data6_sensor          <= (others => '0');
            sensors_sensor        <= (others => '0');
        elsif rising_edge(sensor_clock) then
            capture_toggle_meta   <= capture_toggle;
            capture_toggle_sync   <= capture_toggle_meta;
            capture_toggle_sync_d <= capture_toggle_sync;
            capture_pulse_sensor  <= capture_toggle_sync xor capture_toggle_sync_d;
            core_ready_d          <= core_ready;

            if core_ready = '1' and core_ready_d = '0' then
                data0_sensor       <= data0;
                data1_sensor       <= data1;
                data2_sensor       <= data2;
                data3_sensor       <= data3;
                data4_sensor       <= data4;
                data5_sensor       <= data5;
                data6_sensor       <= data6;
                sensors_sensor     <= sensors;
                data_toggle_sensor <= not data_toggle_sensor;
            end if;
        end if;
    end process sensor_clock_process;

    read_process : process(address, read, chipselect, ready_latched, threshold,
                           data0_latched, data1_latched, data2_latched,
                           data3_latched, data4_latched, data5_latched,
                           data6_latched, sensors_latched, pll_locked_sync)
    begin
        readdata <= (others => '0');

        if chipselect = '1' and read = '1' then
            case address is
                when "00" =>
                    readdata(0)           <= ready_latched;
                    readdata(1)           <= pll_locked_sync;
                    readdata(14 downto 8) <= sensors_latched;

                when "01" =>
                    readdata(7 downto 0) <= threshold;

                when "10" =>
                    readdata(7 downto 0)   <= data0_latched;
                    readdata(15 downto 8)  <= data1_latched;
                    readdata(23 downto 16) <= data2_latched;
                    readdata(31 downto 24) <= data3_latched;

                when "11" =>
                    readdata(7 downto 0)   <= data4_latched;
                    readdata(15 downto 8)  <= data5_latched;
                    readdata(23 downto 16) <= data6_latched;

                when others =>
                    readdata <= (others => '0');
            end case;
        end if;
    end process read_process;

    sensor_core : entity work.capteurs_sol_seuil
        port map (
            clk          => sensor_clock,
            reset_n      => core_reset_n,
            data_capture => capture_pulse_sensor,
            data_readyr  => core_ready,
            data0r       => data0,
            data1r       => data1,
            data2r       => data2,
            data3r       => data3,
            data4r       => data4,
            data5r       => data5,
            data6r       => data6,
            NIVEAU       => threshold,
            vect_capt    => sensors,
            ADC_CONVSTr  => ADC_CONVST,
            ADC_SCK      => ADC_SCK,
            ADC_SDIr     => ADC_SDI,
            ADC_SDO      => ADC_SDO
        );
end architecture rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
    signal capture_pulse : std_logic := '0';
    signal threshold     : std_logic_vector(7 downto 0) := x"80";

    signal core_ready : std_logic;
    signal data0      : std_logic_vector(7 downto 0);
    signal data1      : std_logic_vector(7 downto 0);
    signal data2      : std_logic_vector(7 downto 0);
    signal data3      : std_logic_vector(7 downto 0);
    signal data4      : std_logic_vector(7 downto 0);
    signal data5      : std_logic_vector(7 downto 0);
    signal data6      : std_logic_vector(7 downto 0);
    signal sensors    : std_logic_vector(6 downto 0);

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
    write_process : process(clock, reset_n)
    begin
        if reset_n = '0' then
            capture_pulse  <= '0';
            threshold      <= x"80";
            ready_latched  <= '0';
            data0_latched  <= (others => '0');
            data1_latched  <= (others => '0');
            data2_latched  <= (others => '0');
            data3_latched  <= (others => '0');
            data4_latched  <= (others => '0');
            data5_latched  <= (others => '0');
            data6_latched  <= (others => '0');
            sensors_latched <= (others => '0');
        elsif rising_edge(clock) then
            capture_pulse <= '0';

            if core_ready = '1' then
                ready_latched   <= '1';
                data0_latched   <= data0;
                data1_latched   <= data1;
                data2_latched   <= data2;
                data3_latched   <= data3;
                data4_latched   <= data4;
                data5_latched   <= data5;
                data6_latched   <= data6;
                sensors_latched <= sensors;
            end if;

            if chipselect = '1' and write = '1' then
                case address is
                    when "00" =>
                        if byteenable(0) = '1' then
                            if writedata(0) = '1' then
                                capture_pulse <= '1';
                                ready_latched <= '0';
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
    end process write_process;

    read_process : process(address, read, chipselect, ready_latched, threshold,
                           data0_latched, data1_latched, data2_latched,
                           data3_latched, data4_latched, data5_latched,
                           data6_latched, sensors_latched)
    begin
        readdata <= (others => '0');

        if chipselect = '1' and read = '1' then
            case address is
                when "00" =>
                    readdata(0)           <= ready_latched;
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
            clk          => clock,
            reset_n      => reset_n,
            data_capture => capture_pulse,
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

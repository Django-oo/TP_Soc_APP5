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
    constant SCK_DIV_CYCLES       : integer := 250; -- 50 MHz / (2 * 250) = 100 kHz
    constant CONV_WAIT_CYCLES     : integer := 100;
    constant CONV_LOW_WAIT_CYCLES : integer := 20;

    type state_t is (
        ST_IDLE,
        ST_CONV_HIGH,
        ST_CONV_LOW,
        ST_SCK_LOW,
        ST_SCK_HIGH,
        ST_FRAME_DONE
    );

    type channel_array_t is array (0 to 6) of std_logic_vector(11 downto 0);

    signal state : state_t := ST_IDLE;

    signal threshold       : std_logic_vector(7 downto 0) := x"80";
    signal ready_latched   : std_logic := '0';
    signal busy_reg        : std_logic := '0';
    signal capture_request : std_logic := '0';

    signal data_latched : channel_array_t := (others => (others => '0'));
    signal data_work    : channel_array_t := (others => (others => '0'));
    signal sensors      : std_logic_vector(6 downto 0);

    signal active_channel : unsigned(2 downto 0) := (others => '0');
    signal command_word   : std_logic_vector(5 downto 0) := (others => '0');
    signal pass_index     : std_logic := '0';

    signal conv_counter : integer range 0 to CONV_WAIT_CYCLES := 0;
    signal low_counter  : integer range 0 to CONV_LOW_WAIT_CYCLES := 0;
    signal sck_counter  : integer range 0 to SCK_DIV_CYCLES := 0;
    signal bit_index    : integer range 0 to 11 := 0;
    signal rx_shift     : std_logic_vector(11 downto 0) := (others => '0');

    signal adc_convst_i : std_logic := '0';
    signal adc_sck_i    : std_logic := '0';
    signal adc_sdi_i    : std_logic := '0';

    function make_command(ch : unsigned(2 downto 0)) return std_logic_vector is
        variable cmd : std_logic_vector(5 downto 0);
    begin
        cmd(5) := '1';              -- single-ended
        cmd(4) := std_logic(ch(0));
        cmd(3) := std_logic(ch(2));
        cmd(2) := std_logic(ch(1));
        cmd(1) := '1';              -- unipolar
        cmd(0) := '0';              -- no sleep
        return cmd;
    end function;
begin
    ADC_CONVST <= adc_convst_i;
    ADC_SCK    <= adc_sck_i;
    ADC_SDI    <= adc_sdi_i;

    threshold_bits : for i in 0 to 6 generate
    begin
        sensors(i) <= '1' when unsigned(data_latched(i)(11 downto 4)) > unsigned(threshold) else '0';
    end generate threshold_bits;

    read_process : process(address, chipselect, read, ready_latched, busy_reg, threshold, data_latched, sensors, ADC_SDO)
    begin
        readdata <= (others => '0');

        if chipselect = '1' and read = '1' then
            case address is
                when "00" =>
                    readdata(0)           <= ready_latched;
                    readdata(1)           <= busy_reg;
                    readdata(14 downto 8) <= sensors;
                    readdata(16)          <= ADC_SDO;

                when "01" =>
                    readdata(7 downto 0) <= threshold;

                when "10" =>
                    readdata(7 downto 0)   <= data_latched(0)(11 downto 4);
                    readdata(15 downto 8)  <= data_latched(1)(11 downto 4);
                    readdata(23 downto 16) <= data_latched(2)(11 downto 4);
                    readdata(31 downto 24) <= data_latched(3)(11 downto 4);

                when "11" =>
                    readdata(7 downto 0)   <= data_latched(4)(11 downto 4);
                    readdata(15 downto 8)  <= data_latched(5)(11 downto 4);
                    readdata(23 downto 16) <= data_latched(6)(11 downto 4);

                when others =>
                    readdata <= (others => '0');
            end case;
        end if;
    end process read_process;

    process(clock, reset_n)
        variable next_channel : unsigned(2 downto 0);
    begin
        if reset_n = '0' then
            state           <= ST_IDLE;
            threshold       <= x"80";
            ready_latched   <= '0';
            busy_reg        <= '0';
            capture_request <= '0';
            data_latched    <= (others => (others => '0'));
            data_work       <= (others => (others => '0'));
            active_channel  <= (others => '0');
            command_word    <= (others => '0');
            pass_index      <= '0';
            conv_counter    <= 0;
            low_counter     <= 0;
            sck_counter     <= 0;
            bit_index       <= 0;
            rx_shift        <= (others => '0');
            adc_convst_i    <= '0';
            adc_sck_i       <= '0';
            adc_sdi_i       <= '0';
        elsif rising_edge(clock) then
            if chipselect = '1' and write = '1' then
                case address is
                    when "00" =>
                        if byteenable(0) = '1' then
                            if writedata(0) = '1' and busy_reg = '0' then
                                capture_request <= '1';
                                ready_latched   <= '0';
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

            case state is
                when ST_IDLE =>
                    adc_convst_i <= '0';
                    adc_sck_i    <= '0';
                    adc_sdi_i    <= '0';
                    conv_counter <= 0;
                    low_counter  <= 0;
                    sck_counter  <= 0;
                    bit_index    <= 0;

                    if capture_request = '1' then
                        capture_request <= '0';
                        busy_reg        <= '1';
                        ready_latched   <= '0';
                        data_work       <= (others => (others => '0'));
                        active_channel  <= (others => '0');
                        command_word    <= make_command(to_unsigned(0, 3));
                        pass_index      <= '0';
                        rx_shift        <= (others => '0');
                        adc_convst_i    <= '1';
                        state           <= ST_CONV_HIGH;
                    end if;

                when ST_CONV_HIGH =>
                    adc_convst_i <= '1';
                    adc_sck_i    <= '0';

                    if conv_counter >= CONV_WAIT_CYCLES - 1 then
                        conv_counter <= 0;
                        adc_convst_i <= '0';
                        state        <= ST_CONV_LOW;
                    else
                        conv_counter <= conv_counter + 1;
                    end if;

                when ST_CONV_LOW =>
                    adc_convst_i <= '0';
                    adc_sck_i    <= '0';

                    if low_counter >= CONV_LOW_WAIT_CYCLES - 1 then
                        low_counter <= 0;
                        sck_counter <= 0;
                        bit_index   <= 0;
                        rx_shift    <= (others => '0');
                        adc_sdi_i   <= command_word(5);
                        state       <= ST_SCK_LOW;
                    else
                        low_counter <= low_counter + 1;
                    end if;

                when ST_SCK_LOW =>
                    adc_sck_i <= '0';

                    if sck_counter >= SCK_DIV_CYCLES - 1 then
                        sck_counter <= 0;
                        adc_sck_i   <= '1';
                        state       <= ST_SCK_HIGH;
                    else
                        sck_counter <= sck_counter + 1;
                    end if;

                when ST_SCK_HIGH =>
                    adc_sck_i <= '1';

                    if sck_counter >= SCK_DIV_CYCLES - 1 then
                        sck_counter <= 0;
                        rx_shift(11 - bit_index) <= ADC_SDO;
                        adc_sck_i <= '0';

                        if bit_index >= 11 then
                            state <= ST_FRAME_DONE;
                        else
                            bit_index <= bit_index + 1;

                            if bit_index + 1 < 6 then
                                adc_sdi_i <= command_word(5 - (bit_index + 1));
                            else
                                adc_sdi_i <= '0';
                            end if;

                            state <= ST_SCK_LOW;
                        end if;
                    else
                        sck_counter <= sck_counter + 1;
                    end if;

                when ST_FRAME_DONE =>
                    adc_convst_i <= '0';
                    adc_sck_i    <= '0';
                    adc_sdi_i    <= '0';

                    if pass_index = '0' then
                        pass_index   <= '1';
                        conv_counter <= 0;
                        low_counter  <= 0;
                        rx_shift     <= (others => '0');
                        adc_convst_i <= '1';
                        state        <= ST_CONV_HIGH;
                    else
                        data_work(to_integer(active_channel)) <= rx_shift;

                        if active_channel = to_unsigned(6, 3) then
                            data_latched(0) <= data_work(0);
                            data_latched(1) <= data_work(1);
                            data_latched(2) <= data_work(2);
                            data_latched(3) <= data_work(3);
                            data_latched(4) <= data_work(4);
                            data_latched(5) <= data_work(5);
                            data_latched(6) <= rx_shift;
                            busy_reg        <= '0';
                            ready_latched   <= '1';
                            state           <= ST_IDLE;
                        else
                            next_channel  := active_channel + 1;
                            active_channel <= next_channel;
                            command_word   <= make_command(next_channel);
                            pass_index     <= '0';
                            conv_counter   <= 0;
                            low_counter    <= 0;
                            rx_shift       <= (others => '0');
                            adc_convst_i   <= '1';
                            state          <= ST_CONV_HIGH;
                        end if;
                    end if;
            end case;
        end if;
    end process;
end architecture rtl;

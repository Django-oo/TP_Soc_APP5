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

    type channel_array_t is array (0 to 7) of std_logic_vector(11 downto 0);

    signal state : state_t := ST_IDLE;

    signal control_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal channel_reg   : unsigned(2 downto 0) := (others => '0');
    signal data_reg      : std_logic_vector(11 downto 0) := (others => '0');
    signal channel_data  : channel_array_t := (others => (others => '0'));
    signal busy_reg      : std_logic := '0';
    signal done_reg      : std_logic := '0';
    signal pending_start : std_logic := '0';

    signal requested_channel : unsigned(2 downto 0) := (others => '0');
    signal command_word      : std_logic_vector(5 downto 0) := (others => '0');
    signal pass_index        : std_logic := '0';

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

    read_process : process(address, chipselect, read, control_reg, channel_reg, data_reg, busy_reg, done_reg, ADC_SDO)
        variable control_value : std_logic_vector(31 downto 0);
    begin
        readdata <= (others => '0');
        control_value := control_reg;
        control_value(0) := '0';

        if chipselect = '1' and read = '1' then
            case address is
                when "00" =>
                    readdata <= control_value;

                when "01" =>
                    readdata(2 downto 0) <= std_logic_vector(channel_reg);

                when "10" =>
                    readdata(11 downto 0) <= data_reg;

                when "11" =>
                    readdata(0) <= busy_reg;
                    readdata(1) <= done_reg;
                    readdata(2) <= ADC_SDO;

                when others =>
                    readdata <= (others => '0');
            end case;
        end if;
    end process read_process;

    process(clock, reset_n)
    begin
        if reset_n = '0' then
            state             <= ST_IDLE;
            control_reg       <= (others => '0');
            channel_reg       <= (others => '0');
            data_reg          <= (others => '0');
            channel_data      <= (others => (others => '0'));
            busy_reg          <= '0';
            done_reg          <= '0';
            pending_start     <= '0';
            requested_channel <= (others => '0');
            command_word      <= (others => '0');
            pass_index        <= '0';
            conv_counter      <= 0;
            low_counter       <= 0;
            sck_counter       <= 0;
            bit_index         <= 0;
            rx_shift          <= (others => '0');
            adc_convst_i      <= '0';
            adc_sck_i         <= '0';
            adc_sdi_i         <= '0';
        elsif rising_edge(clock) then
            if chipselect = '1' and write = '1' then
                case address is
                    when "00" =>
                        if byteenable(0) = '1' then
                            control_reg(7 downto 1) <= writedata(7 downto 1);
                            control_reg(0) <= '0';

                            if writedata(0) = '1' and busy_reg = '0' then
                                pending_start <= '1';
                                done_reg <= '0';
                            end if;
                        end if;

                        if byteenable(1) = '1' then
                            control_reg(15 downto 8) <= writedata(15 downto 8);
                        end if;

                        if byteenable(2) = '1' then
                            control_reg(23 downto 16) <= writedata(23 downto 16);
                        end if;

                        if byteenable(3) = '1' then
                            control_reg(31 downto 24) <= writedata(31 downto 24);
                        end if;

                    when "01" =>
                        if byteenable(0) = '1' then
                            channel_reg <= unsigned(writedata(2 downto 0));
                        end if;

                    when "11" =>
                        if byteenable(0) = '1' and writedata(1) = '1' then
                            done_reg <= '0';
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

                    if pending_start = '1' then
                        pending_start     <= '0';
                        busy_reg          <= '1';
                        done_reg          <= '0';
                        requested_channel <= channel_reg;
                        command_word      <= make_command(channel_reg);
                        pass_index        <= '0';
                        rx_shift          <= (others => '0');
                        adc_convst_i      <= '1';
                        state             <= ST_CONV_HIGH;
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
                        data_reg <= rx_shift;
                        channel_data(to_integer(requested_channel)) <= rx_shift;
                        busy_reg <= '0';
                        done_reg <= '1';
                        state    <= ST_IDLE;
                    end if;
            end case;
        end if;
    end process;
end architecture rtl;

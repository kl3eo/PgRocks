CREATE OR REPLACE FUNCTION NEWORD (INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) RETURNS NUMERIC AS '
DECLARE
no_w_id		ALIAS FOR $1;	
no_max_w_id	ALIAS FOR $2;
no_d_id		ALIAS FOR $3;
no_c_id		ALIAS FOR $4;
no_o_ol_cnt	ALIAS FOR $5;
no_d_next_o_id	ALIAS FOR $6;
no_c_discount	NUMERIC;
no_c_last	VARCHAR;
no_c_credit	VARCHAR;
no_d_tax	NUMERIC;
no_w_tax	NUMERIC;
tstamp		TIMESTAMP;
no_ol_supply_w_id	INTEGER;
no_ol_i_id		NUMERIC;
no_ol_quantity		NUMERIC;
no_o_all_local		INTEGER;
o_id			INTEGER;
no_i_name		VARCHAR(24);
no_i_price		NUMERIC(5,2);
no_i_data		VARCHAR(50);
no_s_quantity		NUMERIC(6);
no_ol_amount		NUMERIC(6,2);
no_s_dist_01		CHAR(24);
no_s_dist_02		CHAR(24);
no_s_dist_03		CHAR(24);
no_s_dist_04		CHAR(24);
no_s_dist_05		CHAR(24);
no_s_dist_06		CHAR(24);
no_s_dist_07		CHAR(24);
no_s_dist_08		CHAR(24);
no_s_dist_09		CHAR(24);
no_s_dist_10		CHAR(24);
no_ol_dist_info		CHAR(24);
no_s_data		VARCHAR(50);
x			NUMERIC;
rbk			NUMERIC;
BEGIN
--assignment below added due to error in appendix code
no_o_all_local := 0;
SELECT c_discount, c_last, c_credit, w_tax
INTO no_c_discount, no_c_last, no_c_credit, no_w_tax
FROM customer, warehouse
WHERE warehouse.w_id = no_w_id AND customer.c_w_id = no_w_id AND
customer.c_d_id = no_d_id AND customer.c_id = no_c_id;
UPDATE district SET d_next_o_id = d_next_o_id + 1 WHERE d_id = no_d_id AND d_w_id = no_w_id RETURNING d_next_o_id, d_tax INTO no_d_next_o_id, no_d_tax;
o_id := no_d_next_o_id;
INSERT INTO ORDERS (key, mark, o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt, o_all_local) VALUES ((select cast( rocks_get_node_number()*10000000000000000+ EXTRACT(EPOCH FROM current_timestamp)*1000000 as bigint)),1,o_id, no_d_id, no_w_id, no_c_id, current_timestamp, no_o_ol_cnt, no_o_all_local);
INSERT INTO NEW_ORDER (no_o_id, no_d_id, no_w_id) VALUES (o_id, no_d_id, no_w_id);
--#2.4.1.4
rbk := round(DBMS_RANDOM(1,100));
--#2.4.1.5
FOR loop_counter IN 1 .. no_o_ol_cnt
LOOP
IF ((loop_counter = no_o_ol_cnt) AND (rbk = 1))
THEN
no_ol_i_id := 100001;
ELSE
no_ol_i_id := round(DBMS_RANDOM(1,100000));
END IF;
--#2.4.1.5.2
x := round(DBMS_RANDOM(1,100));
IF ( x > 1 )
THEN
no_ol_supply_w_id := no_w_id;
ELSE
no_ol_supply_w_id := no_w_id;
--no_all_local is actually used before this point so following not beneficial
no_o_all_local := 0;
WHILE ((no_ol_supply_w_id = no_w_id) AND (no_max_w_id != 1))
LOOP
no_ol_supply_w_id := round(DBMS_RANDOM(1,no_max_w_id));
END LOOP;
END IF;
--#2.4.1.5.3
no_ol_quantity := round(DBMS_RANDOM(1,10));
SELECT i_price, i_name, i_data INTO no_i_price, no_i_name, no_i_data
FROM item WHERE i_id = no_ol_i_id;
SELECT s_quantity, s_data, s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05, s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10
INTO no_s_quantity, no_s_data, no_s_dist_01, no_s_dist_02, no_s_dist_03, no_s_dist_04, no_s_dist_05, no_s_dist_06, no_s_dist_07, no_s_dist_08, no_s_dist_09, no_s_dist_10 FROM stock WHERE s_i_id = no_ol_i_id AND s_w_id = no_ol_supply_w_id;
IF ( no_s_quantity > no_ol_quantity )
THEN
no_s_quantity := ( no_s_quantity - no_ol_quantity );
ELSE
no_s_quantity := ( no_s_quantity - no_ol_quantity + 91 );
END IF;
UPDATE stock SET s_quantity = no_s_quantity
WHERE s_i_id = no_ol_i_id
AND s_w_id = no_ol_supply_w_id;

no_ol_amount := (  no_ol_quantity * no_i_price * ( 1 + no_w_tax + no_d_tax ) * ( 1 - no_c_discount ) );

IF no_d_id = 1
THEN 
no_ol_dist_info := no_s_dist_01; 

ELSIF no_d_id = 2
THEN
no_ol_dist_info := no_s_dist_02;

ELSIF no_d_id = 3
THEN
no_ol_dist_info := no_s_dist_03;

ELSIF no_d_id = 4
THEN
no_ol_dist_info := no_s_dist_04;

ELSIF no_d_id = 5
THEN
no_ol_dist_info := no_s_dist_05;

ELSIF no_d_id = 6
THEN
no_ol_dist_info := no_s_dist_06;

ELSIF no_d_id = 7
THEN
no_ol_dist_info := no_s_dist_07;

ELSIF no_d_id = 8
THEN
no_ol_dist_info := no_s_dist_08;

ELSIF no_d_id = 9
THEN
no_ol_dist_info := no_s_dist_09;

ELSIF no_d_id = 10
THEN
no_ol_dist_info := no_s_dist_10;
END IF;

INSERT INTO order_line (ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_dist_info)
VALUES (o_id, no_d_id, no_w_id, loop_counter, no_ol_i_id, no_ol_supply_w_id, no_ol_quantity, no_ol_amount, no_ol_dist_info);

END LOOP;
RETURN no_s_quantity;
EXCEPTION
WHEN serialization_failure OR deadlock_detected OR no_data_found
THEN ROLLBACK;
END; 
' LANGUAGE 'plpgsql';

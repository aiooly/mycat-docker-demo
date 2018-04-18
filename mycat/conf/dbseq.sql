DROP TABLE IF EXISTS mycat_sequence;
CREATE TABLE mycat_sequence (
	name varchar(50) NOT NULL,
	current_value int(11) NOT NULL,
	increment int(11) NOT NULL DEFAULT 1,
	PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO mycat_sequence (name, current_value, increment) VALUES ('USER', 0, 1);
INSERT INTO mycat_sequence (name, current_value, increment) VALUES ('ORDERS', 0, 1);

-- ----------------------------
-- Function structure for `mycat_seq_currval`
-- ----------------------------
DROP FUNCTION IF EXISTS `mycat_seq_currval`;
DELIMITER ;;
CREATE FUNCTION `mycat_seq_currval`(seq_name VARCHAR(64)) RETURNS varchar(64) CHARSET latin1
    DETERMINISTIC
BEGIN
    DECLARE retval VARCHAR(64);
    SET retval="-1,0";
    SELECT concat(CAST(current_value AS CHAR),",",CAST(increment AS CHAR) ) INTO retval FROM mycat_sequence  WHERE name = seq_name;
    RETURN retval ;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for `mycat_seq_nextval`
-- ----------------------------
DROP FUNCTION IF EXISTS `mycat_seq_nextval`;
DELIMITER ;;
CREATE FUNCTION `mycat_seq_nextval`(seq_name VARCHAR(64)) RETURNS varchar(64) CHARSET latin1
    DETERMINISTIC
BEGIN
    DECLARE retval VARCHAR(64);
    DECLARE val BIGINT;
    DECLARE inc INT;
    DECLARE seq_lock INT;
    set val = -1;
    set inc = 0;
    SET seq_lock = -1;
    SELECT GET_LOCK(seq_name, 15) into seq_lock;
    if seq_lock = 1 then
      SELECT current_value + increment, increment INTO val, inc FROM mycat_sequence WHERE name = seq_name for update;
      if val != -1 then
          UPDATE mycat_sequence SET current_value = val WHERE name = seq_name;
      end if;
      SELECT RELEASE_LOCK(seq_name) into seq_lock;
    end if;
    SELECT concat(CAST((val - inc + 1) as CHAR),",",CAST(inc as CHAR)) INTO retval;
    RETURN retval;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for `mycat_seq_setvals`
-- ----------------------------
DROP FUNCTION IF EXISTS `mycat_seq_nextvals`;
DELIMITER ;;
CREATE FUNCTION `mycat_seq_nextvals`(seq_name VARCHAR(64), count INT) RETURNS VARCHAR(64) CHARSET latin1
    DETERMINISTIC
BEGIN
    DECLARE retval VARCHAR(64);
    DECLARE val BIGINT;
    DECLARE seq_lock INT;
    SET val = -1;
    SET seq_lock = -1;
    SELECT GET_LOCK(seq_name, 15) into seq_lock;
    if seq_lock = 1 then
        SELECT current_value + count INTO val FROM mycat_sequence WHERE name = seq_name for update;
        IF val != -1 THEN
            UPDATE mycat_sequence SET current_value = val WHERE name = seq_name;
        END IF;
        SELECT RELEASE_LOCK(seq_name) into seq_lock;
    end if;
    SELECT CONCAT(CAST((val - count + 1) as CHAR), ",", CAST(val as CHAR)) INTO retval;
    RETURN retval;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for `mycat_seq_setval`
-- ----------------------------
DROP FUNCTION IF EXISTS `mycat_seq_setval`;
DELIMITER ;;
CREATE FUNCTION `mycat_seq_setval`(seq_name VARCHAR(64), value BIGINT) RETURNS varchar(64) CHARSET latin1
    DETERMINISTIC
BEGIN
    DECLARE retval VARCHAR(64);
    DECLARE inc INT;
    SET inc = 0;
    SELECT increment INTO inc FROM mycat_sequence WHERE name = seq_name;
    UPDATE mycat_sequence SET current_value = value WHERE name = seq_name;
    SELECT concat(CAST(value as CHAR),",",CAST(inc as CHAR)) INTO retval;
    RETURN retval;
END
;;
DELIMITER ;

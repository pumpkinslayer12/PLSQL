--KRIS RUTHERFORD
--HW 10
SET serveroutput ON size 1000000
/
--PROBLEM 1
--PROCEDURE TO ACCEPT USER INPUT THEN CREATE A COLUMN BASED UPON THAT
--IN ANOTHER SCHEMA TABLE
CREATE OR REPLACE
PROCEDURE kr_hw10_1
  (
    tbl_name VARCHAR2,
    col_name VARCHAR2,
    col_type VARCHAR2)
IS
  qry VARCHAR2(500);
BEGIN
  --ALTER TABLE QUERY THAT WILL ADD A COLUMN ONTO A TABLE
  --HAVE TO USE NOOP FOR DATA TYPES AS IT KEPT SAYING INVALID DATATYPE WHENEVER IT WAS PASSED TO THE BIND VARIABLE.
  qry:= 'ALTER TABLE ' || DBMS_ASSERT.SIMPLE_SQL_NAME(tbl_name)|| ' ADD ' || DBMS_ASSERT.SIMPLE_SQL_NAME(col_name) || ' ' || DBMS_ASSERT.NOOP(col_type);
  --EXECUTES QUERY
  EXECUTE immediate qry;
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Error please check process');
END kr_hw10_1;
/
EXECUTE kr_hw10_1('BB_SHOPPER','MEMEBER', 'CHAR(1)');
/
DESC BB_SHOPPER;
/
--PROBLEM 2
--PROCEDURE THAT ACCEPTS A DYNAMIC VALUE TO SEARCH BB_SHOPPER
CREATE OR REPLACE
PROCEDURE kr_hw10_2
  (
    col_name VARCHAR2,
    val      VARCHAR2)
IS
type rcd
IS
  record
  (
    c_id   INT,
    l_name VARCHAR2(15));
  qry_rcd rcd;
  csr sys_refcursor;
  qry VARCHAR2(500);
BEGIN
  --DYNAMIC QUERY
  qry:= 'SELECT idshopper, lastname FROM BB_SHOPPER WHERE ' || dbms_assert.simple_sql_name(col_name)||' = :val';
  --PASSES DYNAMIC QUERY TO REFERANCE CURSOR
  OPEN csr FOR qry USING val;
  -- LOOPS THROUGH CURSOR AND DISPLAYS RESULTS
  LOOP
    FETCH csr INTO qry_rcd;
    EXIT
  WHEN csr%notfound;
    dbms_output.put_line('Customer ID: ' || qry_rcd.c_id || ' Last name: ' || qry_rcd.l_name);
  END LOOP;
  CLOSE csr;
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Error please check process');
END kr_hw10_2;
/
EXECUTE kr_hw10_2('STATE','NC');
/
EXECUTE kr_hw10_2('EMAIL', 'ratboy@msn.net');
/
--PROBLEM 3
--CREATE PACKAGE TO STORE RECORDS
CREATE OR REPLACE
PACKAGE kr_pkg
IS
  --RECORD TO STORE RESULTS OF QUERY
type rcd
IS
  record
  (
    c_id   INT,
    l_name VARCHAR2(15));
  --TABLE HOLD MULTIPLE RECORDS RECORD
type tbl
IS
  TABLE OF rcd;
END kr_pkg;
/
--PROCEDURE THAT TAKES IN TABLE AND PASSES QUERY RESULTS TO IT.
CREATE OR REPLACE
PROCEDURE kr_hw10_3
  (
    col_name VARCHAR2,
    val      VARCHAR2,
    qry_tbl IN OUT kr_pkg.tbl)
            IS
  csr sys_refcursor;
  qry VARCHAR2(500);
BEGIN
  --DYNAMIC QUERY
  qry:= 'SELECT idshopper, lastname FROM BB_SHOPPER WHERE ' || dbms_assert.simple_sql_name(col_name)||' = :val';
  --PASSES DYNAMIC QUERY TO REFERANCE CURSOR
  OPEN csr FOR qry USING val;
  -- BULK COLLECTS CURSOR INTO TABLE
  FETCH csr bulk collect INTO qry_tbl;
  
  CLOSE csr;
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Error please check process');
END kr_hw10_3;
/
--FUNCTION TAKES IN SEARCH CRITERIA AND PIPELINES THE RETURNED TABLE TO BE USED
--IN SQL SCOPE
CREATE OR REPLACE
  FUNCTION kr_hw10_3a
    (
      col_name VARCHAR2,
      val      VARCHAR2)
    RETURN kr_pkg.tbl pipelined
  IS
    qry_tbl kr_pkg.tbl;
  BEGIN
    --CALLS AND PASSES A TABLE TO GET RESULTS FROM PROCEDRUE
    kr_hw10_3(col_name, val, qry_tbl);
    --LOOPS THROUGH AND PIPELINES RESULT TABLE TO BE USED BY QUERY
    FOR i IN 1..qry_tbl.count
    LOOP
      pipe row(qry_tbl(i));
    END LOOP;
    RETURN;
  EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('Error please check process');
  END kr_hw10_3a;
  /
  --TEST CASES
  SELECT C_ID AS Customer_ID,
    l_name    AS Last_Name
  FROM TABLE(kr_hw10_3a('STATE','NC'));
  /
  SELECT C_ID AS Customer_ID,
    l_name    AS Last_Name
  FROM TABLE(kr_hw10_3a('EMAIL', 'ratboy@msn.net'));
  /
  --PROBLEM 4
  --PROCEDURE THAT WILL ACCEPT A FIRST NAME, LAST NAME, CITY, STATE, AND ZIP CODE AND ADD THEM
  --TO BB_SHOPPERS ROW WITH INSERT
CREATE OR REPLACE
PROCEDURE kr_hw10_4
  (
    f_name VARCHAR2,
    l_name VARCHAR2,
    city   VARCHAR2,
    state  VARCHAR2,
    zip    VARCHAR2)
IS
  qry  VARCHAR2(500);
  c    INTEGER :=dbms_sql.open_cursor;
  fdbk INTEGER;
BEGIN
  SAVEPOINT a;
  --INSERT TEXT FOR BB_SHOPPER
  qry:='INSERT INTO BB_SHOPPER(idshopper, firstname, lastname, city, state, zipcode) ' || 'VALUES(bb_shopper_seq.nextval, :f_name, :l_name, :city, :state, :zip)';
  --PARSES THE QUERY
  dbms_sql.parse(c,qry,dbms_sql.native);
  --SETS BIND VARIABLES
  dbms_sql.bind_variable(c,'f_name',f_name);
  dbms_sql.bind_variable(c,'l_name',l_name);
  dbms_sql.bind_variable(c,'city',city);
  dbms_sql.bind_variable(c,'state',state);
  dbms_sql.bind_variable(c,'zip',zip);
  --ASSIGNS FEEDBACK OF INSERT STATEMENT
  fdbk:= dbms_sql.execute(c);
  dbms_sql.close_cursor(c);
  IF fdbk=1 THEN
    DBMS_OUTPUT.PUT_LINE('ROW COMMITTED');
    COMMIT;
  ELSE
    --IF THERE WAS NOTHING INSERTED
    ROLLBACK TO a;
  END IF;
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Error Rollback in process');
  ROLLBACK TO a;
END kr_hw10_4;
/
--TESTS
--INSERTS A NEW ROW
EXECUTE kr_hw10_4('bob', 'barker', 'Shiny', 'HI', '12345');
/
--CHECKS RESULTS
SELECT idshopper,
  firstname,
  lastname,
  address,
  city,
  state,
  zipcode
FROM bb_shopper
WHERE ROWNUM=1
ORDER BY idshopper DESC;
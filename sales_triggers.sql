--KRIS RUTHERFORD
--HW8
SET SERVEROUTPUT ON SIZE 100000
/
--PROBLEM 1
CREATE OR REPLACE TRIGGER hw8_1 AFTER LOGON ON SCHEMA
  BEGIN
    --LOGS USER AFTER LOGIN WITH THE USER NAME AND THE SYSDATE
    INSERT
    INTO bb_audit_logon VALUES
      (
        sys.login_user,
        SYSDATE
      );
  END hw8_1;
  /
  --CHECKS SCHEMA INFORMATION
  SELECT *
  FROM user_triggers
  WHERE trigger_name = 'hw8_1';
  /
  --CHECK THAT LOGOFF OCCURED
  SELECT * FROM bb_audit_logon;
  /
  --PROBLEM 2
  --TABLE PROVIDED IN HOMEWORK TO CREATE
CREATE TABLE bb_sales_sum ( idProduct NUMBER(2), tot_sales NUMBER(7,2), tot_qty NUMBER(5,2) );
  /
  INSERT INTO bb_sales_sum
    (idProduct, tot_sales, tot_qty
    ) VALUES
    (6, 100, 10
    );
  /
  INSERT INTO bb_sales_sum
    (idProduct, tot_sales, tot_qty
    ) VALUES
    (8, 100, 10
    );
  /
  COMMIT;
  /
CREATE OR REPLACE TRIGGER hw8_2 AFTER
  UPDATE OF orderplaced ON bb_basket FOR EACH ROW WHEN(old.orderplaced=0
  AND new.orderplaced                                                 =1) DECLARE
    --PROVIDES CONTROL BETWEEN NEW ROW OR OVERIDE FOR bb_sales_sum
    control NUMBER(1,0) := 0;
  --CURSOR EXTRACT HALF AND WHOLE WEIGHT
  --AGGREGATES THEM TOGETHER INTO A FINAL TOTAL WITH UNION
  CURSOR all_items(basketid bb_basketitem.idbasketitem%TYPE)
  IS
    SELECT idproduct           AS idp,
      SUM(price   *(quantity*.5)) AS ttl,
      SUM(quantity*.5)            AS qty
    FROM bb_basketitem
    WHERE idbasket=basketid
    AND OPTION1   =1
    GROUP BY idproduct
  
  UNION
  
  SELECT idproduct      AS idp,
    SUM(price*quantity) AS ttl,
    SUM(quantity)       AS qty
  FROM bb_basketitem
  WHERE idbasket=basketid
  AND OPTION1   =2
  GROUP BY idproduct;
  --CHECKS IF PRODUCT ID IS IN THE BB_SALES_SUM TABLE
  CURSOR check_total(prodid bb_product.idproduct%type)
  IS
    SELECT tot_sales,tot_qty FROM bb_sales_sum WHERE idproduct=prodid;
BEGIN
  FOR i IN all_items(:NEW.idbasket)
  LOOP
    FOR j IN check_total(i.idp)
    LOOP
      --UPDATES TOTALS TO THE BB_SALES_SUM
      --HAPPENS IF A PRODUCT ALREADY EXISTS IN TABLE
      UPDATE bb_sales_sum
      SET tot_sales  = j.tot_sales+i.ttl,
        tot_qty      = j.tot_qty  +i.qty
      WHERE IDPRODUCT=i.idp;
      
      control :=1;
      --PUSHES TO THE END OF THE LOOP
    END LOOP;
    --HAPPENS IF NEW ROW NEEDS TO BE ADDED
    IF control = 0 THEN
      --WHAT WILL OCCUR IF THERE EXISTS NO VALUES IN THE TABLE.
      INSERT
      INTO bb_sales_sum VALUES
        (
          i.idp,
          i.ttl,
          i.qty
        );
      --RESETS CONTROL
    ELSE
      control:=0;
    END IF;
  END LOOP;
END hw8_2;
/
SELECT * FROM bb_sales_sum;
/
--RESETS VALUES
UPDATE bb_basket
SET orderplaced=0
WHERE idbasket =3
OR idbasket    =6;
/
UPDATE bb_basket SET orderplaced=1 WHERE idbasket=3 OR idbasket=6;
/
SELECT * FROM bb_sales_sum;
/
--PROBLEM 3
--OBJECT TYPE TO HOLD INFORMATION ON SALES
CREATE OR REPLACE TYPE sales_dates
IS
  OBJECT
  (
    productid NUMBER,
    s_start DATE,
    s_end DATE);
  /
  --TABLE TO HOLD SALES DATES
CREATE OR REPLACE TYPE sales_dates_table
IS
  TABLE OF sales_dates;
  /
CREATE OR REPLACE TRIGGER hw8_3 FOR UPDATE OF salestart,
  saleend ON bb_product COMPOUND TRIGGER
  --VARIABLE TO ASSOCIATE WITH PREVIOUS TABLE
  tbl sales_dates_table := sales_dates_table();
  BEFORE STATEMENT
IS
  --QUERY THAT FILLS ARRAY TO BE REFERANCED BY OTHER TRIGGERS
  CURSOR table_fill
  IS
    SELECT idproduct, salestart,saleend FROM bb_product;
BEGIN
  --LOOP FILLS TABLE
  FOR i IN table_fill
  LOOP
    tbl.extend;
    --ASSIGNS SALES DATES OBJECT TO TABLE
    tbl(tbl.last) :=sales_dates(i.idproduct,i.salestart,i.saleend);
  END LOOP;
END BEFORE STATEMENT;
--END SUBTRIGGER
BEFORE EACH ROW
IS
  --TO HAVE SOMETHING TO TEST IF RECORD IS FOUND
  dummy bb_product.idproduct%TYPE;
  --CURSOR TO REFERANCE GLOBAL ARRAY
  --MAKES SURE THAT NEW SALE DATES DO NOT OVERLAP WITH THE START AND END DATES OF SALES
  CURSOR check_dates(prodid bb_product.idproduct%TYPE, sale_start DATE, sale_end DATE)
  IS
    SELECT productid
    FROM TABLE(tbl)
    WHERE productid=prodid
    AND (s_start BETWEEN sale_start AND sale_end
    OR s_end BETWEEN sale_start AND sale_end);
BEGIN
  OPEN check_dates(:new.idproduct,:new.salestart,:new.saleend);
  FETCH check_dates INTO dummy;
  --CHECKS FOR DATE CONFLICTS AND START/END DATE ANOMOLIES
  IF dummy IS NOT NULL OR :new.saleend <= :new.salestart THEN
    CLOSE check_dates;
    raise_application_error (-20999,'There was an error with the sales dates. Please check the order and there are no conflicts.');
  END IF;
  CLOSE check_dates;
END BEFORE EACH ROW;
--END SUBTRIGGER
END hw8_3;
/
BEGIN
  --VALID UPDATE
  UPDATE bb_product
  SET SALESTART  = SYSDATE,
    SALEEND      =SYSDATE +2
  WHERE IDPRODUCT=1;
  --INVALID UPDATE
  UPDATE bb_product
  SET SALESTART  = SYSDATE+1,
    SALEEND      =SYSDATE +3
  WHERE IDPRODUCT=1;
EXCEPTION
  --DISPLAYS ERROR MESSAGE TO USERS
WHEN OTHERS THEN
  --DISPLAYS ERROR MESSAGE TO USER
  dbms_output.put_line(SQLERRM);
END;
/
--CHECKS RESULTS
SELECT * FROM bb_product WHERE IDPRODUCT = 1;
/
ROLLBACK;
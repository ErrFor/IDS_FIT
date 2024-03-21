-- IDS SQL Projekt
-- Autori: Sniehovskyi Nikita (xsnieh00) a Yaroslav Slabik (xsnieh00)
-- Zadani: Firma (1.)

DROP TABLE Oddeleni             CASCADE CONSTRAINTS;
DROP TABLE Pracovnik            CASCADE CONSTRAINTS;
DROP TABLE Zakazka              CASCADE CONSTRAINTS;
DROP TABLE VyrizenaZakazka      CASCADE CONSTRAINTS;
DROP TABLE NevyrizenaZakazka    CASCADE CONSTRAINTS;
DROP TABLE EmployeesWorkloads   CASCADE CONSTRAINTS;
DROP TABLE Firma                CASCADE CONSTRAINTS;
DROP TABLE Klient               CASCADE CONSTRAINTS;
DROP TABLE Ucet                 CASCADE CONSTRAINTS;
DROP TABLE Naklady              CASCADE CONSTRAINTS;
DROP TABLE Prijmy               CASCADE CONSTRAINTS;

DROP SEQUENCE seq_cislo_oddeleni;
DROP SEQUENCE seq_cislo_zakazky;
DROP SEQUENCE seq_cislo_nakladu;
DROP SEQUENCE seq_cislo_prijmu;

DROP MATERIALIZED VIEW statistika_pracovniku;

CREATE SEQUENCE seq_cislo_oddeleni
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_cislo_zakazky
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_cislo_nakladu
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE SEQUENCE seq_cislo_prijmu
    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;


CREATE TABLE Firma (
    ICO             INT             PRIMARY KEY,
    Majitel         VARCHAR(32)     NOT NULL,
    Datum_zalozeni  DATE            NOT NULL,
    Adresa          VARCHAR(64)     NOT NULL
);

CREATE TABLE Oddeleni (
    cislo       INTEGER PRIMARY KEY,
    zamereni    VARCHAR(32) NOT NULL UNIQUE,

    ICO_firmy   INT,
    FOREIGN KEY (ICO_firmy) REFERENCES Firma (ICO)
        ON DELETE SET NULL
); 

CREATE OR REPLACE TRIGGER OnInsert_Oddeleni
    BEFORE INSERT ON Oddeleni
    FOR EACH ROW
BEGIN
    :NEW.cislo := seq_cislo_oddeleni.NEXTVAL;
END;
/


CREATE TABLE Pracovnik (
    cislo_op    INTEGER     PRIMARY KEY,
    jmeno       VARCHAR(16) NOT NULL,
    datum_nar   DATE        NOT NULL,
    pozice      VARCHAR(32),

    fk_cislo_oddeleni INTEGER,
    FOREIGN KEY (fk_cislo_oddeleni) REFERENCES Oddeleni (cislo)
        ON DELETE SET NULL
); 

CREATE TABLE Klient (
    ICO         INT PRIMARY KEY CHECK (ICO > 0 and ICO < 99999999),
    Firma_ICO   INT,
    
    FOREIGN KEY (Firma_ICO) REFERENCES Firma(ICO)
);

-- Hlavni tabulka pro zakazky
CREATE TABLE Zakazka (
    cislo       INTEGER PRIMARY KEY,
    datum_zal   DATE    NOT NULL,
    priorita    INTEGER DEFAULT 99,

    klient_ICO  INT,
    FOREIGN KEY (klient_ICO) REFERENCES Klient(ICO)
);


CREATE OR REPLACE TRIGGER OnInsert_Zakazka
    BEFORE INSERT ON Zakazka
    FOR EACH ROW
BEGIN
    :NEW.cislo := seq_cislo_zakazky.NEXTVAL;
END;
/

-- Pokud objednavka je vyrizena, k puvodni tabulce doplnime informace
CREATE TABLE VyrizenaZakazka (
    cislo               INTEGER,
    datum_dokonceni     DATE    NOT NULL,

    PRIMARY KEY (cislo),
    FOREIGN KEY (cislo) REFERENCES Zakazka (cislo)
        ON DELETE SET NULL
);

-- Nova objednavka ma informace, zbytecne k ukladani po vyrizeni, tuto informace pozdeji smazeme
CREATE TABLE NevyrizenaZakazka (
    cislo               INTEGER,
    predpokl_termin     DATE        NOT NULL,
    akt_stav            VARCHAR(64) NOT NULL,

    PRIMARY KEY (cislo),
    FOREIGN KEY (cislo) REFERENCES Zakazka (cislo)
        ON DELETE SET NULL
);

-- Pomocna tabulka se zaznamy o tom, kteri praconvikach resi ktere zakazky
CREATE TABLE EmployeesWorkloads (
    cislo_pracovnika    INTEGER,
    cislo_zakazky       INTEGER,

    PRIMARY KEY (cislo_pracovnika, cislo_zakazky),
    FOREIGN KEY (cislo_pracovnika) REFERENCES Pracovnik (cislo_op)
        ON DELETE SET NULL,

    FOREIGN KEY (cislo_zakazky) REFERENCES Zakazka (cislo)
        ON DELETE SET NULL
);

-- Pro realizaci generalizace mezi "Ucet", "Naklady" a "Prijmy" byl zvolen přístup "Třídní tabulka".
CREATE TABLE Ucet (
    cislo       VARCHAR(17) PRIMARY KEY CHECK (REGEXP_LIKE(cislo, '^[0-9]{6}/[0-9]{2,10}')),
    Majitel     VARCHAR(32) NOT NULL,
    Firma_ICO   INT,
    FOREIGN KEY (Firma_ICO) REFERENCES Firma(ICO)
);


-- Tabulka "Ucet" obsahuje společné atributy, zatímco "Naklady" a "Prijmy" uchovávají specifické atributy.
CREATE TABLE Naklady (
    cislo               VARCHAR(17),
    Rozsah              VARCHAR(16) NOT NULL,
    Popis               VARCHAR(64) NOT NULL,
    Stav                VARCHAR(16) NOT NULL,
    Ucet_cislo          VARCHAR(17),
    Oddeleni_cislo      INT,

    PRIMARY KEY (cislo),
    FOREIGN KEY (Ucet_cislo)            REFERENCES Ucet(cislo),
    FOREIGN KEY (Oddeleni_cislo)        REFERENCES Oddeleni(cislo)
);

CREATE OR REPLACE TRIGGER OnInsert_Naklady
    BEFORE INSERT ON Naklady
    FOR EACH ROW
BEGIN
    :NEW.cislo := seq_cislo_nakladu.NEXTVAL;
END;
/

-- Primární klíč "cislo" z "Ucet" je také použit v "Naklady" a "Prijmy" pro udržení integrity dat.
CREATE TABLE Prijmy (
    cislo               VARCHAR(17),
    Rozsah              VARCHAR(16) NOT NULL,
    Popis               VARCHAR(64) NOT NULL,
    Stav                VARCHAR(16) NOT NULL,
    Ucet_cislo          VARCHAR(17),
    Zakazka_cislo       INT,

    PRIMARY KEY (cislo),
    FOREIGN KEY (Ucet_cislo)    REFERENCES Ucet(cislo),
    FOREIGN KEY (Zakazka_cislo) REFERENCES Zakazka(cislo)
);

CREATE OR REPLACE TRIGGER OnInsert_Prijmy
    BEFORE INSERT ON Prijmy
    FOR EACH ROW
BEGIN
    :NEW.cislo := seq_cislo_prijmu.NEXTVAL;
END;
/

-- 4. Cast

-- TRIGGER pro kontrolu věku zaměstnance před vložením do tabulky Pracovnik
CREATE OR REPLACE TRIGGER Check_Age_Before_Insert
    BEFORE INSERT ON Pracovnik
    FOR EACH ROW
DECLARE
    age INTEGER;
BEGIN
    age := TRUNC(MONTHS_BETWEEN(SYSDATE, :NEW.datum_nar) / 12);
    IF age < 18 THEN
        RAISE_APPLICATION_ERROR(-20001, 'The employee must be over 18 years old.');
    END IF;
END;
/

-- TRIGGER pro kontrolu data vytvoření objednávky před vložením do tabulky Zakazka
CREATE OR REPLACE TRIGGER Check_Date_Before_Insert
    BEFORE INSERT ON Zakazka
    FOR EACH ROW
BEGIN
    IF :NEW.datum_zal > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20002, 'The order creation date cannot be later than the current date.');
    END IF;
END;
/

-- Ukazkova data
INSERT INTO Firma 
    VALUES('17500','Petr Novak',TO_DATE('2022-04-07', 'YYYY-MM-DD'),'Hubesova 3, Brno');

-- Oddeleni
INSERT INTO Oddeleni 
    VALUES(NULL,'Hlavni kancelar','17500');

INSERT INTO Oddeleni 
    VALUES(NULL,'Vyvoj web. stranek','17500');

INSERT INTO Oddeleni 
    VALUES(NULL,'Software testing','17500');

-- Pracovniky prvniho oddeleni
INSERT INTO Pracovnik
    VALUES('990634564','Zdenek Novak',TO_DATE('1955-02-25', 'YYYY-MM-DD'), 'Reditel firmy', '1');
INSERT INTO Pracovnik
    VALUES('990634572','Jiri Novak',TO_DATE('1958-04-02', 'YYYY-MM-DD'), 'Marketingovy manazer', '1');
INSERT INTO Pracovnik
    VALUES('990686487','Jan Novak',TO_DATE('1969-11-09', 'YYYY-MM-DD'), 'Manazer skoupeni', '1');

-- Pracovniky druheho oddeleni
INSERT INTO Pracovnik
    VALUES('990646853','Milan Novak',TO_DATE('1970-08-03', 'YYYY-MM-DD'), 'Hlavni inzenyr', '2');
INSERT INTO Pracovnik
    VALUES('990614278','Radomir Novak',TO_DATE('1978-11-20', 'YYYY-MM-DD'), 'Junior web. dev.', '2');
INSERT INTO Pracovnik
    VALUES('990696528','Petr Novak',TO_DATE('1987-05-22', 'YYYY-MM-DD'), 'Freelance junior web. dev.', '2');
INSERT INTO Pracovnik
    VALUES('990604513','Marie Novakova',TO_DATE('1979-07-14', 'YYYY-MM-DD'), 'Senior web. dev.', '2');

-- Pracovniky druheho oddeleni
INSERT INTO Pracovnik
    VALUES('990686578','Lukas Novak',TO_DATE('1965-02-12', 'YYYY-MM-DD'), 'Software testing inzenyr', '3');
INSERT INTO Pracovnik
    VALUES('990614714','Jaroslav Novak',TO_DATE('1969-02-01', 'YYYY-MM-DD'), 'Bug finder', '3');
INSERT INTO Pracovnik
    VALUES('990601348','Jan Novak',TO_DATE('1969-02-08', 'YYYY-MM-DD'), 'Bug finder 2', '3');

INSERT INTO Klient
    VALUES('22350','17500');
INSERT INTO Klient
    VALUES('44275','17500');
INSERT INTO Klient
    VALUES('49529','17500');

INSERT INTO Zakazka
    VALUES(NULL,TO_DATE('2019-05-08',  'YYYY-MM-DD'), NULL,'22350');
INSERT INTO VyrizenaZakazka
    VALUES('1',TO_DATE('2019-05-24', 'YYYY-MM-DD'));

-- Dva oddeleni na jedne zakazce
INSERT INTO EmployeesWorkloads VALUES('990601348','1');
INSERT INTO EmployeesWorkloads VALUES('990696528','1');
INSERT INTO EmployeesWorkloads VALUES('990614714','1');

INSERT INTO Zakazka
    VALUES(NULL,TO_DATE('2019-06-01',  'YYYY-MM-DD'), NULL,'44275');
INSERT INTO VyrizenaZakazka
    VALUES('2',TO_DATE('2019-07-22', 'YYYY-MM-DD'));
    
-- Jedno oddeleni
INSERT INTO EmployeesWorkloads VALUES('990646853','2');
INSERT INTO EmployeesWorkloads VALUES('990604513','2');

INSERT INTO Zakazka
    VALUES(NULL,TO_DATE('2019-06-07',  'YYYY-MM-DD'), NULL,'49529');
INSERT INTO VyrizenaZakazka
    VALUES('3',TO_DATE('2019-08-15', 'YYYY-MM-DD'));
    
INSERT INTO EmployeesWorkloads VALUES('990614714','3');

INSERT INTO Zakazka
    VALUES(NULL,TO_DATE('2019-06-12',  'YYYY-MM-DD'), NULL,'22350');
INSERT INTO VyrizenaZakazka
    VALUES('4',TO_DATE('2019-07-05', 'YYYY-MM-DD'));
    
-- Tri oddeleni na jedne zakazce
INSERT INTO EmployeesWorkloads VALUES('990634572','4');
INSERT INTO EmployeesWorkloads VALUES('990646853','4');
INSERT INTO EmployeesWorkloads VALUES('990604513','4');
INSERT INTO EmployeesWorkloads VALUES('990686578','4');
INSERT INTO EmployeesWorkloads VALUES('990614714','4');


INSERT INTO Zakazka
    VALUES(NULL,TO_DATE('2019-06-03', 'YYYY-MM-DD'), NULL,'44275');
INSERT INTO NevyrizenaZakazka
    VALUES('5',TO_DATE('2019-08-22', 'YYYY-MM-DD'), 'Navrh');

UPDATE NevyrizenaZakazka
SET akt_stav = 'Implementace'
WHERE cislo = 2;

INSERT INTO EmployeesWorkloads VALUES('990646853','5');
INSERT INTO EmployeesWorkloads VALUES('990604513','5');


INSERT INTO Zakazka
    VALUES(NULL,TO_DATE('2019-06-27', 'YYYY-MM-DD'), NULL,'22350');
INSERT INTO NevyrizenaZakazka
    VALUES('6',TO_DATE('2019-08-01', 'YYYY-MM-DD'), 'Navrh');

INSERT INTO EmployeesWorkloads VALUES('990601348','6');
INSERT INTO EmployeesWorkloads VALUES('990686578','6');
INSERT INTO EmployeesWorkloads VALUES('990614714','6');


INSERT INTO Zakazka
    VALUES(NULL,TO_DATE('2019-07-03', 'YYYY-MM-DD'), NULL,'22350');
INSERT INTO NevyrizenaZakazka
    VALUES('7',TO_DATE('2019-07-21', 'YYYY-MM-DD'), 'Sber tymu');

INSERT INTO EmployeesWorkloads VALUES('990601348','7');
INSERT INTO EmployeesWorkloads VALUES('990604513','7');
INSERT INTO EmployeesWorkloads VALUES('990686578','7');

INSERT INTO Ucet
    VALUES('123456/1234','Petr Novak','17500');

INSERT INTO Naklady
    VALUES('1','18000','Mzda, Milan Novak, 01.2020','Zaplaceno','123456/1234','2');
INSERT INTO Naklady
    VALUES('2','14000','Mzda, Radomir Novak, 01.2020','Zaplaceno','123456/1234','2');
INSERT INTO Naklady
    VALUES('3','18000','Mzda, Petr Novak, 01.2020','Zaplaceno','123456/1234','2');
INSERT INTO Naklady
    VALUES('4','40000','Mzda, Lukas Novak, 01.2020','Zaplaceno','123456/1234','3');
INSERT INTO Naklady
    VALUES('5','24000','Mzda, Jan Novak, 01.2020','Zaplaceno','123456/1234','3');
INSERT INTO Naklady
    VALUES('6','35000','Mzda, Zdenek Novak, 01.2020','Zaplaceno','123456/1234','1');

INSERT INTO Prijmy
    VALUES('1','50000','Zakazka c.2','Zaplaceno','123456/1234','2');
INSERT INTO Prijmy
    VALUES('2','2000','Zakazka c.7','Zaplaceno','123456/1234','7');
INSERT INTO Prijmy
    VALUES('3','670000','Zakazka c.5','Zaplaceno','123456/1234','5');
INSERT INTO Prijmy
    VALUES('4','84000','Zakazka c.4','Zaplaceno','123456/1234','4');

/*
-- 3. Cast


-- 1. SELECT dotaz spojující dvě tabulky: seznam pracovníků, kteří pracují na nevyřízených objednávkách
-- (Spojení tabulek: Pracovnik a EmployeesWorkloads)
SELECT p.jmeno, p.pozice, ew.cislo_zakazky
FROM Pracovnik p
JOIN EmployeesWorkloads ew ON p.cislo_op = ew.cislo_pracovnika
WHERE ew.cislo_zakazky IN (SELECT cislo FROM NevyrizenaZakazka);

-- 2. SELECT dotaz spojující dvě tabulky: celková cena objednávek pro každého zákazníka
-- (Spojení tabulek: Zakazka a Prijmy)
SELECT z.klient_ICO, SUM(p.Rozsah) as total_cost
FROM Zakazka z
JOIN Prijmy p ON z.cislo = p.Zakazka_cislo
GROUP BY z.klient_ICO;

-- 3. SELECT dotaz spojující tři tabulky: seznam objednávek, které jsou vykonávány každým oddělením
-- (Spojení tabulek: Oddeleni, Pracovnik a EmployeesWorkloads)
SELECT o.zamereni, p.pozice, p.jmeno, ew.cislo_zakazky
FROM Oddeleni o
JOIN Pracovnik p ON o.cislo = p.fk_cislo_oddeleni
JOIN EmployeesWorkloads ew ON p.cislo_op = ew.cislo_pracovnika;

-- 4. SELECT dotaz s použitím GROUP BY a agregátové funkce: počet objednávek vykonávaných každým zaměstnancem
SELECT ew.cislo_pracovnika, p.jmeno, COUNT(ew.cislo_zakazky) as num_orders
FROM EmployeesWorkloads ew
JOIN Pracovnik p ON ew.CISLO_PRACOVNIKA = p.CISLO_OP
GROUP BY ew.cislo_pracovnika, p.jmeno;

-- 5. SELECT dotaz s použitím GROUP BY a agregátové funkce: celková cena nákladů pro každé oddělení
SELECT n.Oddeleni_cislo, SUM(n.Rozsah) as total_expense
FROM Naklady n
GROUP BY n.Oddeleni_cislo;

-- 6. SELECT dotaz s použitím predikátu EXISTS: seznam zákazníků, kteří mají alespoň jednu nevyřízenou objednávku
SELECT k.*
FROM Klient k
WHERE EXISTS (  SELECT 1 FROM Zakazka z
                JOIN NevyrizenaZakazka nz
                ON z.cislo = nz.cislo
                WHERE k.ICO = z.klient_ICO  );

-- 7. SELECT dotaz s použitím predikátu IN a vnořeným SELECT: seznam zaměstnanců, kteří nemají žádné nevyřízené objednávky
SELECT p.*
FROM Pracovnik p
WHERE p.cislo_op NOT IN (   SELECT ew.cislo_pracovnika
                            FROM EmployeesWorkloads ew
                            WHERE ew.cislo_zakazky 
                            IN (SELECT cislo FROM NevyrizenaZakazka) );*/

-- PROCEDURE pro přidání vyrizené objednávky, pokud její číslo ještě neexistuje v tabulce VyrizenaZakazka
CREATE OR REPLACE PROCEDURE insert_vyrizena_zakazka (
    p_cislo              INTEGER,
    p_datum_dokonceni    DATE
)
IS
    v_count  INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM VyrizenaZakazka
    WHERE cislo = p_cislo;

    IF v_count = 0 THEN
        INSERT INTO VyrizenaZakazka (cislo, datum_dokonceni)
        VALUES (p_cislo, p_datum_dokonceni);
    ELSE
        RAISE_APPLICATION_ERROR(-20003, 'The order with such a number has already been completed.');
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END insert_vyrizena_zakazka;
/

-- PROCEDURE pro zobrazení všech dokončených objednávek
CREATE OR REPLACE PROCEDURE list_vyrizene_zakazky
IS
    CURSOR c_vyrizene_zakazky
    IS
        SELECT * FROM VyrizenaZakazka;

    v_zakazka c_vyrizene_zakazky%ROWTYPE;
BEGIN
    OPEN c_vyrizene_zakazky;
    LOOP
        FETCH c_vyrizene_zakazky INTO v_zakazka;
        EXIT WHEN c_vyrizene_zakazky%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('Order number: ' || v_zakazka.cislo || ', сompletion date: ' || v_zakazka.datum_dokonceni);
    END LOOP;

    CLOSE c_vyrizene_zakazky;
EXCEPTION
    WHEN OTHERS THEN
        CLOSE c_vyrizene_zakazky;
        RAISE;
END list_vyrizene_zakazky;
/

-- Vkládáme dokončenou objednávku s číslem 7 a datem 2023-04-01
BEGIN
    insert_vyrizena_zakazka(7, TO_DATE('2023-04-01', 'YYYY-MM-DD'));
END;
/

-- Zobrazujeme informace o všech dokončených objednávkách
SET SERVEROUTPUT ON;
BEGIN
    list_vyrizene_zakazky;
END;
/

-- Vytvoření indexu pro optimalizaci výkonu při vyhledávání v tabulce EmployeesWorkloads
CREATE INDEX idx_employees_workloads ON EmployeesWorkloads (cislo_zakazky);

-- Dotaz SELECT zobrazující pozici, zaměření oddělení a počet zatížení zaměstnanců pro konkrétní zakázku
SELECT p.pozice, o.zamereni, COUNT(ew.cislo_pracovnika) as workload_count
FROM EmployeesWorkloads ew
JOIN Pracovnik p ON ew.cislo_pracovnika = p.cislo_op
JOIN Oddeleni o ON p.fk_cislo_oddeleni = o.cislo
WHERE ew.cislo_zakazky = 1
GROUP BY p.pozice, o.zamereni;

-- Zobrazení plánu pro výše uvedený dotaz, který umožňuje optimalizovat výkon dotazu
EXPLAIN PLAN FOR
SELECT p.pozice, o.zamereni, COUNT(ew.cislo_pracovnika) as workload_count
FROM EmployeesWorkloads ew
JOIN Pracovnik p ON ew.cislo_pracovnika = p.cislo_op
JOIN Oddeleni o ON p.fk_cislo_oddeleni = o.cislo
WHERE ew.cislo_zakazky = 1
GROUP BY p.pozice, o.zamereni;

-- Zobrazení plánu provádění dotazu
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());


-- Komplexní dotaz SELECT pro získání informací o objednávkách, jejich statusu a počtu zaměstnanců, kteří na nich pracují
WITH OrderEmployees AS (
    SELECT
        z.cislo AS OrderNumber,
        COUNT(DISTINCT ew.cislo_pracovnika) AS EmployeeCount
    FROM
        Zakazka z
        JOIN EmployeesWorkloads ew ON z.cislo = ew.cislo_zakazky
    GROUP BY
        z.cislo
)
SELECT
    z.cislo AS OrderNumber,
    z.datum_zal AS OrderDate,
    k.ICO AS ClientICO,
    -- Rozhodnutí o stavu objednávky (dokončeno nebo nedokončeno) pomocí operátoru CASE
    CASE
        WHEN vz.cislo IS NOT NULL THEN 'Completed'
        ELSE 'Not Completed'
    END AS OrderStatus,
    oe.EmployeeCount
FROM
    Zakazka z
    LEFT JOIN VyrizenaZakazka vz ON z.cislo = vz.cislo
    LEFT JOIN NevyrizenaZakazka nvz ON z.cislo = nvz.cislo
    JOIN Klient k ON z.klient_ICO = k.ICO
    JOIN EmployeesWorkloads ew ON z.cislo = ew.cislo_zakazky
    JOIN Pracovnik p ON ew.cislo_pracovnika = p.cislo_op
    JOIN OrderEmployees oe ON z.cislo = oe.OrderNumber
GROUP BY
    z.cislo,
    z.datum_zal,
    k.ICO,
    vz.cislo,
    oe.EmployeeCount
-- Řazení výsledků podle čísla objednávky    
ORDER BY
    z.cislo;

select * from table(dbms_xplan.display_cursor(sql_id=>'4kpbxq8mvgypp', format=>'ALLSTATS LAST'));


-- Přístupové data pro druhého člena týmu

GRANT ALL ON Oddeleni           TO xsnieh00;
GRANT ALL ON Pracovnik          TO xsnieh00;
GRANT ALL ON Zakazka            TO xsnieh00;
GRANT ALL ON VyrizenaZakazka    TO xsnieh00;
GRANT ALL ON NevyrizenaZakazka  TO xsnieh00;
GRANT ALL ON EmployeesWorkloads TO xsnieh00;
GRANT ALL ON Firma              TO xsnieh00;
GRANT ALL ON Klient             TO xsnieh00;
GRANT ALL ON Ucet               TO xsnieh00;
GRANT ALL ON Naklady            TO xsnieh00;
GRANT ALL ON Prijmy             TO xsnieh00;


-- Materialized view

CREATE MATERIALIZED VIEW statistika_pracovniku 
REFRESH FORCE ON DEMAND AS
SELECT ew.cislo_pracovnika, p.jmeno, COUNT(ew.cislo_zakazky) as num_orders
FROM EmployeesWorkloads ew
JOIN Pracovnik p ON ew.CISLO_PRACOVNIKA = p.CISLO_OP
    WHERE ew.cislo_zakazky IN
    ( SELECT vz.cislo FROM VyrizenaZakazka vz )
GROUP BY ew.cislo_pracovnika, p.jmeno;

SELECT * FROM statistika_pracovniku;

-- Insert new data
INSERT INTO Zakazka
    VALUES(NULL,TO_DATE('2019-06-13',  'YYYY-MM-DD'), NULL,'22350');
INSERT INTO VyrizenaZakazka
    VALUES('8',TO_DATE('2019-07-06', 'YYYY-MM-DD'));
INSERT INTO EmployeesWorkloads VALUES('990601348','8');
    
-- Nothing changed because materialized view doesn't update itself
-- So we need to update it
EXECUTE DBMS_MVIEW.REFRESH('statistika_pracovniku');

SELECT * FROM statistika_pracovniku;

-- EXECUTE DBMS_SNAPSHOT.REFRESH('statistika_pracovniku','f'); 
GRANT ALL ON statistika_pracovniku TO xsnieh00;

select * from table(dbms_xplan.display_cursor(sql_id=>'39vgrd8wspqr3', format=>'ALLSTATS LAST'));

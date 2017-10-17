SET ECHO ON
SET SERVEROUTPUT ON

CREATE OR REPLACE PROCEDURE LICZ_BRUTTO_NA_FAKTURZE(ID_FAKTURY NUMBER) IS
  WARTOSC_NETTO NUMBER(6,2);
  WARTOSC_VAT NUMBER(6,2);
  WARTOSC_BRUTTO NUMBER(6,2);
  BEGIN
    SELECT DISTINCT SUM(PRODUKT.CENA_NETTO) INTO WARTOSC_NETTO FROM PRODUKT,FAKTURA,DANE_FAKTURY
    WHERE PRODUKT.ID=DANE_FAKTURY.PRODUKT_ID AND DANE_FAKTURY.FAKTURA_ID=ID_FAKTURY
    GROUP BY FAKTURA.ID;
    WARTOSC_BRUTTO:=WARTOSC_NETTO * 1.08;
    WARTOSC_VAT:=WARTOSC_BRUTTO-WARTOSC_NETTO;
    UPDATE FAKTURA SET CENA_NETTO = WARTOSC_NETTO WHERE FAKTURA.ID=ID_FAKTURY;
    UPDATE FAKTURA SET VAT = WARTOSC_VAT WHERE FAKTURA.ID=ID_FAKTURY;
    UPDATE FAKTURA SET CENA_BRUTTO = WARTOSC_BRUTTO WHERE FAKTURA.ID=ID_FAKTURY;
    DBMS_OUTPUT.PUT_LINE('WARTOSC NETTO: '||WARTOSC_NETTO);
    DBMS_OUTPUT.PUT_LINE('WARTOSC VAT: '||WARTOSC_VAT);
    DBMS_OUTPUT.PUT_LINE('WARTOSC BRUTTO: '||WARTOSC_BRUTTO);
  END;
/

SET SERVEROUTPUT ON
CREATE OR REPLACE PROCEDURE PODLICZENIE_OKRESOWE(DATA1 VARCHAR2, DATA2 VARCHAR2) IS
  NETTO NUMBER(10,2);
  BRUTTO NUMBER(10,2);
  VAT NUMBER(10,2);
  ILOSC_SZT INT;
BEGIN
  SELECT DISTINCT SUM(CENA_NETTO),SUM(ILOSC_PRODUKTOW) INTO NETTO,ILOSC_SZT FROM WARTOSCI_FAKTUR
  WHERE DATA_WYSTAWIENIA  BETWEEN TO_DATE(DATA1,'YYYY/MM/DD') AND TO_DATE(DATA2,'YYYY/MM/DD');
  BRUTTO:=NETTO*1.08;
  VAT:=BRUTTO-NETTO;
  DBMS_OUTPUT.PUT_LINE('ZAROBEK NETTO W PODANYM OKRESIE: ' || NETTO || ' ZL.');
  DBMS_OUTPUT.PUT_LINE('ZAROBEK BRUTTO W PODANYM OKRESIE: '|| BRUTTO || ' ZL.');
  DBMS_OUTPUT.PUT_LINE('VAT DO ZAPLACENIA W PODANYM OKRESIE: ' || VAT || ' ZL.');
  DBMS_OUTPUT.PUT_LINE('ILOSC SPRZEDANYCH SZTUK ZA PODANY OKRES: ' || ILOSC_SZT || ' SZT.');
END;
/

CREATE OR REPLACE PROCEDURE PODWYZKA_PRACOWNIKOW(KWOTA_PODWYZKI NUMBER,STANOWISKOP VARCHAR2) IS
CURSOR KURSOR1 IS SELECT * FROM DANE_PRACOWNIKA
WHERE STANOWISKO=STANOWISKOP FOR UPDATE;
TEMP1 DANE_PRACOWNIKA%ROWTYPE;
I INT:=0;
  BEGIN
    OPEN KURSOR1;
    LOOP
      FETCH KURSOR1 INTO TEMP1;
      EXIT WHEN KURSOR1%NOTFOUND;
      UPDATE DANE_PRACOWNIKA SET DANE_PRACOWNIKA.PENSJA = DANE_PRACOWNIKA.PENSJA + KWOTA_PODWYZKI
      WHERE CURRENT OF KURSOR1;
      I:=I+1;
    END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE OBLICZANIE_BRUTTO_VAT AS

CURSOR KURSOR1 IS SELECT * FROM PRODUKT FOR UPDATE;
CURSOR KURSOR2 IS SELECT * FROM PRODUKT WHERE VAT IS NULL FOR UPDATE;
TEMP1 PRODUKT%ROWTYPE;
TEMP2 PRODUKT%ROWTYPE;
I INT:=0;
J INT:=0;
  BEGIN
    OPEN KURSOR1;
    OPEN KURSOR2;
    LOOP
      FETCH KURSOR1 INTO TEMP1;
      EXIT WHEN KURSOR1%NOTFOUND;
      UPDATE PRODUKT SET PRODUKT.CENA_BRUTTO = PRODUKT.CENA_NETTO * 1.08
      WHERE CURRENT OF KURSOR1;
      I:=I+1;
    END LOOP;
    LOOP
      FETCH KURSOR2 INTO TEMP2;
      EXIT WHEN KURSOR2%NOTFOUND;
      UPDATE PRODUKT SET PRODUKT.VAT = PRODUKT.CENA_BRUTTO - PRODUKT.CENA_NETTO
      WHERE CURRENT OF KURSOR2;
      J:=J+1;
    END LOOP;
  CLOSE KURSOR1;
  CLOSE KURSOR2;
END;
/

CREATE OR REPLACE PROCEDURE ZMIANA_CEN_TOWAROW(NR_OPCJI NUMBER ,KWOTA_PODWYZKI_OBNIZKI FLOAT,ID_PRODUKTU NUMBER) AS

CURSOR KURSOR1 IS SELECT * FROM PRODUKT
WHERE ID=ID_PRODUKTU FOR UPDATE;

CURSOR KURSOR2 IS SELECT * FROM PRODUKT
WHERE ID=ID_PRODUKTU AND CENA_NETTO>KWOTA_PODWYZKI_OBNIZKI FOR UPDATE;

TEMP1 PRODUKT%ROWTYPE;
TEMP2 PRODUKT%ROWTYPE;

I INT:=0;
J INT:=0;

  BEGIN
    OPEN KURSOR1;
    OPEN KURSOR2;
    IF NR_OPCJI=1 THEN
      LOOP
        FETCH KURSOR1 INTO TEMP1;
        EXIT WHEN KURSOR1%NOTFOUND;
        UPDATE PRODUKT SET PRODUKT.CENA_NETTO = PRODUKT.CENA_NETTO + KWOTA_PODWYZKI_OBNIZKI
        WHERE CURRENT OF KURSOR1;
        I:=I+1;
      END LOOP;
      UPDATE PRODUKT SET PRODUKT.CENA_BRUTTO=PRODUKT.CENA_NETTO*1.08;
      UPDATE PRODUKT SET PRODUKT.VAT=PRODUKT.CENA_BRUTTO-PRODUKT.CENA_NETTO;
    END IF;
    IF NR_OPCJI=2 THEN
        LOOP
          FETCH KURSOR2 INTO TEMP2;
          EXIT WHEN KURSOR2%NOTFOUND;
          UPDATE PRODUKT SET PRODUKT.CENA_NETTO = PRODUKT.CENA_NETTO - KWOTA_PODWYZKI_OBNIZKI
          WHERE CURRENT OF KURSOR2;
          I:=J+1;
        END LOOP;
      UPDATE PRODUKT SET PRODUKT.CENA_BRUTTO=PRODUKT.CENA_NETTO*1.08;
      UPDATE PRODUKT SET PRODUKT.VAT=PRODUKT.CENA_BRUTTO-PRODUKT.CENA_NETTO;
    END IF;
    IF (NR_OPCJI<1) THEN RAISE_APPLICATION_ERROR(-20001, 'WYBIERZ OPCJE Z ZAKRESU 1-2!'); 
    END IF;
    IF (NR_OPCJI>2) THEN RAISE_APPLICATION_ERROR(-20001, 'WYBIERZ OPCJE Z ZAKRESU 1-2!');
    END IF;
    CLOSE KURSOR1;
    CLOSE KURSOR2;
END;
/

SET ECHO OFF
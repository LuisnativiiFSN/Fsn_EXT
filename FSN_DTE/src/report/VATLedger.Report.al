report 50004 "FSN Generate Legal Ledger"
{
    // version IDSGT1.VAT

    // 
    // 13 enero 2021 add filtro pos store en vatentry

    CaptionML = ENU = 'Generatión Ledger Entries LS',
                ESM = 'Generación de Libro de Movimientos LS';
    ProcessingOnly = true;

    dataset
    {
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Optines)
                {
                    field(CurrentType; CurrentType)
                    {
                        CaptionML = ENU = 'Type',
                                    ESM = 'Tipo';
                        Lookup = true;
                        OptionCaptionML = ENU = 'Purchase,Sales',
                                          ESM = 'Compras,Ventas';
                        ApplicationArea = all;
                    }
                    field(CurrentPeriodYear; CurrentPeriodYear)
                    {
                        CaptionML = ENU = 'Year Period',
                                    ESM = 'Periódo Año';
                        ApplicationArea = all;
                    }
                    field(CurrentPeriodMonth; CurrentPeriodMonth)
                    {
                        CaptionML = ENU = 'Month Period',
                                    ESM = 'Periódo Mes';
                        ApplicationArea = all;
                        OptionCaptionML = ENU = 'January,February,March,April,May,June,July,August,September,October,November,December',
                                          ESM = 'Enero,Febrero,Marzo,Abril,Mayo,Junio,Julio,Agosto,Septiembre,Octubre,Noviembre,Diciembre';
                    }
                    field(Regenerate; Regenerate)
                    {
                        CaptionML = ENU = 'Re generate',
                                    ESM = 'Re generar';
                        ApplicationArea = all;
                    }
                    field(DocNo; DocNo)
                    {
                        ApplicationArea = all;
                        CaptionML = ENU = 'Document No. Filter',
                                    ESM = 'No. Documento Filtro';
                    }
                    field(gFolio; gFolio)
                    {
                        ApplicationArea = all;
                        CaptionML = ENU = 'Start Folio',
                                    ESM = 'Folio Inicial';
                        Visible = false;
                    }
                    field(gPageFolio; gPageFolio)
                    {
                        ApplicationArea = all;
                        CaptionML = ENU = 'Lines per Page',
                                    ESM = 'Lineas por Página';
                        Visible = false;
                    }
                    field(SelectCompany3; Company3rd)
                    {
                        ApplicationArea = all;
                        CaptionML = ENU = '3th Company',
                                    ESM = 'Compania 3ro';
                        TableRelation = Company;

                        trigger OnValidate();
                        var
                            lTEXT01: TextConst ENU = 'Company  may not be the same', ESM = 'Empresa no puede ser la misma';
                        begin
                            IF COMPANYNAME = Company3rd THEN
                                ERROR(lTEXT01);
                        end;
                    }
                    field(pAName; pAName)
                    {
                        ApplicationArea = all;
                        CaptionML = ENU = 'Name',
                                    ESM = 'Nombre';
                        OptionCaptionML = ENU = 'Bill-Name,Sell-Name',
                                          ESM = 'Nombre Pago/Cobro,Nombre Compra/Venta';
                    }
                    field(filtedaate; FilterDate)
                    {
                        ApplicationArea = all;
                        CaptionML = ENU = 'Date Filter',
                                    ESM = 'Filtro Fecha';
                    }
                }
            }
        }

        actions
        {
        }

        trigger OnOpenPage();
        begin
            Regenerate := TRUE;


            gPageFolio := 20;
            gFolio := 1;
        end;
    }

    labels
    {
    }

    trigger OnPostReport();
    begin
        Dura := CURRENTDATETIME - Time1;

        wd.CLOSE;
        COMMIT;
        IF FilterDate <> '' THEN
            MESSAGE(Text005, gLineNo - gLineNoIni, FilterDate, FilterDate, Dura)
        else
            MESSAGE(Text005, gLineNo - gLineNoIni, FiltDate1, FiltDate2, Dura);
    end;

    trigger OnPreReport();
    begin


        RetailSetup.GET;

        IF CurrentPeriodYear = '' THEN
            ERROR(Text001);


        IF NOT EVALUATE(cYear, CurrentPeriodYear) THEN
            ERROR(Text001);

        IF gPageFolio = 0 THEN
            ERROR(Text006);

        IF gFolio = 0 THEN
            ERROR(Text007);

        gPeriod := CurrentPeriodYear + FORMAT(CurrentPeriodMonth + 1);
        IF CurrentPeriodMonth + 1 < 10 THEN
            gPeriod := CurrentPeriodYear + '0' + FORMAT(CurrentPeriodMonth + 1);



        rStatementLegal.RESET;
        rStatementLegal.SETRANGE(Type, CurrentType);
        rStatementLegal.SETRANGE(Period, gPeriod);
        rStatementLegal.SETRANGE("Closed by Entry No.", 0);

        IF DocNo <> '' THEN
            rStatementLegal.SETFILTER("Document No.", DocNo);

        IF FilterDate <> '' THEN
            rStatementLegal.SETFILTER("Document Date", FilterDate);

        IF rStatementLegal.FINDFIRST THEN
            IF Regenerate THEN
                rStatementLegal.DELETEALL
            ELSE BEGIN
                ERROR(Text002, CurrentPeriodMonth + 1, CurrentPeriodYear);
            END;

        Time1 := CURRENTDATETIME;
        GenBook;
    end;

    var
        CurrentType: Option;
        CurrentPeriodYear: Code[10];
        CurrentPeriodMonth: Option;
        Regenerate: Boolean;
        wd: Dialog;
        TEXT05: TextConst ENU = 'Document:  #1###### \   #2##### Of #3#####', ESM = 'Documento:  #1###### \   #2##### de #3#####';
        sdoc: Text[10];
        LenArrayTS: Integer;
        TypeSerie: Record "Document Sub Type";
        ArrayTypeSerie: array[30] of Text[30];
        rStatementLegal: Record "VAT Ledger";
        gPeriod: Code[10];
        Text001: TextConst ENU = 'You must select year', ESM = 'Debe seleccionar Año';
        Text002: TextConst ENU = 'Period %1 %2 Exist Already ', ESM = 'Periódo %1 %2 ya Existe';
        cYear: Integer;
        lday: Integer;
        Text005: TextConst ENU = 'Was Generated %1 Entris, for Period %2 %3 \Duration %4', ESM = 'Se ha generado %1 para el periódo %2 %3\Duración %4';
        gLineNo: Integer;
        FiltDate1: Date;
        FiltDate2: Date;
        rLoc: Record "General Ledger Setup";
        DocNo: Code[200];
        gFolio: Integer;
        gPageFolio: Integer;
        Text006: TextConst ENU = 'You must select Initial Folio', ESM = 'Debe seleccionar Folio Inicial';
        Text007: TextConst ENU = 'You must select Line by Folio> 1', ESM = 'Debe seleccionar Linea por Folio >1';
        SourceCode: Record 242;
        rCompany: Record 79;
        lLedgerSales: Record 21;
        lLedgerPurch: Record 25;
        TypeFACE: Code[20];
        tmpFolioYY: Text[20];
        ExencionTy: Text[50];
        ExencionNo: Text[50];
        //Resolution : Record "50006";
        DocExttmp: Text[50];
        CustLedger2: Record 21;
        VenLedger2: Record 25;
        Skip: Boolean;
        ATOTAL: array[40] of Decimal;
        NameFile: Text[200];
        ExencionValue: Decimal;
        rLedgerSales: Record 21;
        lLine1: Integer;
        lfactor: Decimal;
        stmp1: Text[10];
        stmp2: Text[10];
        stmp3: Text[50];
        stmp4: Text[30];
        stmp5: Text[30];
        gDocType: Text[10];
        rCust: Record 18;
        VATEntry: Record 254;
        gNameClient: Text[110];
        rStamentVAT: Record "VAT Ledger";
        lRegion: Integer;
        rSales: Record 112;
        rPurch: Record 122;
        rSalesCr: Record 114;
        rPuchCr: Record 124;
        rSalesSer: Record 5992;
        rSalesSerCr: Record 5994;
        rFinCharge: Record 304;
        SeriePre: Code[20];
        rLedgerPurch: Record 25;
        rVendor: Record 23;
        rNCC: Record 124;
        ltmp: Integer;
        sced1: Text[30];
        sced2: Text[30];
        iFolio: Integer;
        iLineFolio: Integer;
        rCreditMemo: Record 114;
        rSubType: Record "Document Sub Type";
        //rSubTypeLink : Record "50005";
        gVAT: Text[30];
        SkipEntry: Boolean;
        Company3rd: Text[50];
        IsCompany3rd: Boolean;
        gLineNoIni: Integer;
        CloseVATentry: Integer;
        Text008: TextConst ENU = 'Document %1 do not have Sub Type %2', ESM = 'Documento %1 No tiene Sub Tipo %2';
        Identif1: Text[10];
        Identif2: Text[20];
        IsOther: Boolean;
        LastRateVAT: Decimal;
        pAName: Option Bill,Sell;
        Salesls: Record 99001472;
        FinCharge: Record 304;
        Store: Record 99001470;
        AmountPoliza: Decimal;
        Receipt: Text[50];
        ReceiptRef: Text[50];
        POSterminal: Record 99001471;
        Terminal: Code[20];
        rSubTypeRef: Record "Document Sub Type";
        SaleslsRef: Record 99001472;
        PricesInclRef: Boolean;
        gDispositive: Code[20];
        rSubTypeRef2: Record "Document Sub Type";
        LedgerInforCode: Record 99001478;
        FilterDate: Text;
        Time1: DateTime;
        Time2: DateTime;
        Dura: Duration;
        RetailSetup: Record 10000700;
        LSREXENTA: Boolean;

        subTypeDefa: Record "Document Sub Type";
        gSubTypeInvDefa: Code[20];
        gSubTypeCMDefa: Code[20];

        GeneralSEtup: Record "General Ledger Setup";
        IsDebug: Boolean;
        SaleslsOriginal: Record 99001472;

    procedure ShowDebug(pValor: Text; pvalo2: text; pvalo3: text)
    begin
        if IsDebug then
            Message(StrSubstNo('Debug %1 %2 %3', pValor, pvalo2, pvalo3));
    end;

    procedure SetParameter(pType: Option; pYear: Code[10]; pMonth: Option);
    begin
        CurrentType := pType;
        CurrentPeriodYear := pYear;
        CurrentPeriodMonth := pMonth;
    end;

    procedure GenBook();
    var
        Company: Record 2000000006;
    begin


        rLoc.GET;
        SourceCode.GET;
        rCompany.GET;

        //Imprime las ventas
        wd.OPEN(TEXT05);

        GeneralSEtup.Get();

        IsDebug := false;
        if strpos(GeneralSEtup.Param4, 'vatdebug') > 0 then
            IsDebug := true;



        CASE CurrentPeriodMonth + 1 OF
            1, 3, 5, 7, 8, 10, 12:
                lday := 31;
            2:
                IF (cYear MOD 4) = 0 THEN
                    lday := 29
                ELSE
                    lday := 28;
            4, 6, 9, 11:
                lday := 30;
            ELSE
                lday := 30;
        END;


        FiltDate1 := DMY2DATE(1, CurrentPeriodMonth + 1, cYear);
        FiltDate2 := DMY2DATE(lday, CurrentPeriodMonth + 1, cYear);


        Company.RESET;
        IF Company3rd <> '' THEN
            Company.SETFILTER(Name, '%1|%2', COMPANYNAME, Company3rd)
        ELSE
            Company.SETFILTER(Name, '%1', COMPANYNAME);


        //COMPANYNAME

        IF Company.FINDFIRST THEN
            REPEAT

                IsCompany3rd := FALSE;
                IF Company.Name <> COMPANYNAME THEN IsCompany3rd := TRUE;

                IF CurrentType = 1 THEN
                    GenBookSales(Company.Name);
                IF CurrentType = 0 THEN
                    GenBookPurchase(Company.Name);
            UNTIL Company.NEXT = 0;
    end;

    procedure SplitDocExt(var pDoc: Text; var rSerie: Text; var rFolio: Text; var rFolioYY: Text);
    var
        ii: Integer;
        jj: Integer;
        kk: Integer;
        strtmp: Text;
        Arraystr: array[10] of Text;
        strtmp2: Text[100];
    begin

        strtmp := pDoc;
        kk := 0;
        ii := 0;
        jj := 0;

        jj := STRLEN(pDoc);
        ii := STRPOS(strtmp, '-');

        strtmp2 := '';
        IF ii = 0 THEN BEGIN
            FOR ii := 1 TO jj DO
                IF COPYSTR(strtmp, ii, 1) = ' ' THEN
                    strtmp2 := strtmp2 + '-'
                ELSE
                    strtmp2 := strtmp2 + COPYSTR(strtmp, ii, 1);
            pDoc := strtmp2;
            strtmp := strtmp2;
        END;

        ii := STRPOS(strtmp, '-');




        //////////////Addd - si no tiene
        IF ii = 0 THEN BEGIN
            jj := STRLEN(pDoc);
            ii := 0;
            REPEAT
                ii := ii + 1;
                IF COPYSTR(pDoc, ii, 1) IN ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'] THEN
                    kk := ii;
            UNTIL (kk > 0) OR (ii >= jj);
            IF kk > 1 THEN
                pDoc := COPYSTR(pDoc, 1, kk - 1) + '-' + COPYSTR(pDoc, kk, jj);
        END;

        strtmp := pDoc;
        ii := STRPOS(strtmp, '-');
        IF ii = 1 THEN strtmp := COPYSTR(strtmp, 2);

        ii := 0;
        kk := 0;
        jj := 0;

        REPEAT
            jj := jj + ii;
            ii := STRPOS(strtmp, '-');
            IF ii > 0 THEN BEGIN
                IF kk < 10 THEN BEGIN
                    kk := kk + 1;
                    Arraystr[kk] := COPYSTR(strtmp, 1, ii - 1);
                END;
                strtmp := COPYSTR(strtmp, ii + 1);
            END;
        UNTIL ii = 0;

        ii := STRPOS(strtmp, ' ');
        IF ii > 0 THEN BEGIN
            kk := kk + 1;
            Arraystr[kk] := COPYSTR(strtmp, 1, ii - 1);
            strtmp := COPYSTR(strtmp, ii + 1);
        END;

        kk := kk + 1;
        Arraystr[kk] := strtmp;

        rSerie := '';
        rFolio := '';
        rFolioYY := '';


        IF kk > 0 THEN BEGIN
            //IF STRLEN(Arraystr[kk]) > 8 THEN
            //  rFolio:= COPYSTR(Arraystr[kk],3);
            rFolioYY := Arraystr[kk];
            IF rFolio = '' THEN rFolio := rFolioYY;

            FOR ii := 1 TO kk - 1 DO
                IF rSerie = '' THEN
                    rSerie := Arraystr[ii]
                ELSE
                    rSerie := rSerie + '-' + Arraystr[ii];
        END;

        IF UPPERCASE(Arraystr[1]) = 'FACE' THEN sdoc := 'FCE';
        IF UPPERCASE(Arraystr[1]) = 'NCE' THEN sdoc := 'NCE';
        IF UPPERCASE(Arraystr[1]) = 'NDE' THEN sdoc := 'NDE';


        rSerie := COPYSTR(rSerie, 1, 20);
        rFolio := COPYSTR(rFolio, 1, 20);
    end;

    procedure IsGroupVAT(var VATentry: Record 254; pType: Integer): Boolean;
    var
        copyVATentry: Record 254;
        sAll: Text[1000];
        ii: Integer;
        jj: Integer;
        Ret: Boolean;
        GrVAT: Record 325;
    begin

        copyVATentry.COPYFILTERS(VATentry);

        Ret := FALSE;
        sAll := '';


        CASE pType OF
            //GAS 1
            11:
                sAll := rLoc."Group VAT GAS 1";
            //GAS 2
            12:
                sAll := rLoc."Group VAT GAS 2";
            //Tourist
            13:
                sAll := rLoc."Group VAT Tourist";
            //Alcohol
            14:
                sAll := rLoc."Group VAT Alcohol";
            //ISR
            16:
                sAll := rLoc."Group VAT Ret Inc";
            //RET VAT
            17:
                sAll := rLoc."Group VAT Ret VAT";
            //NS
            18:
                sAll := rLoc."Group VAT NS";
            //Total VAT
            20:
                sAll := rLoc."Group VAT VAT";
        END;

        IF (pType >= 5) THEN
            IF sAll <> '' THEN BEGIN
                copyVATentry.RESET;
                copyVATentry.SETFILTER("VAT Prod. Posting Group", sAll);
                copyVATentry.SETRANGE("Entry No.", VATentry."Entry No.");
                IF copyVATentry.FINDFIRST THEN BEGIN
                    Ret := TRUE;
                    IsOther := TRUE;
                END ELSE
                    Ret := FALSE;
            END;


        IF GrVAT.GET(VATentry."VAT Bus. Posting Group", VATentry."VAT Prod. Posting Group") THEN
            VATentry."EU Service" := GrVAT."EU Service";


        IF (GrVAT."VAT Calculation Type" = GrVAT."VAT Calculation Type"::"Full VAT")
          AND (GrVAT."VAT Calculation Type" <> VATentry."VAT Calculation Type")
          AND (VATentry.Amount = 0) THEN BEGIN
            VATentry.Amount := VATentry.Base;
            VATentry.Base := 0;
        END;

        LastRateVAT := GrVAT."VAT %";

        IF LSREXENTA THEN BEGIN
            VATentry.Amount := 0;
            GrVAT."VAT %" := 0;
            IF VATentry."VAT Prod. Posting Group" IN ['IVA-BX', 'IVA-SX'] THEN BEGIN
                VATentry.Amount := 0;
                VATentry.Base := 0;
            END;
        END;



        IF pType = 1 THEN  //goods
            IF (NOT VATentry."EU Service") AND
              (GrVAT."VAT %" <> 0)
              THEN
                Ret := TRUE;

        IF pType = 2 THEN  //Services
            IF (VATentry."EU Service") AND
            (GrVAT."VAT %" <> 0)
               THEN
                Ret := TRUE;


        IF pType = 3 THEN  //goods excentos
            IF (NOT VATentry."EU Service") AND
              ((GrVAT."VAT %" = 0))
              THEN
                Ret := TRUE;

        IF pType = 4 THEN  //Services Excentos
            IF (VATentry."EU Service") AND
               (GrVAT."VAT %" = 0)
              THEN
                Ret := TRUE;



        EXIT(Ret);
    end;

    procedure GetValueVAT(var VATEntry: Record 254; var VTOTAL: array[40] of Decimal; lfactor: Decimal; VTIP: Code[20]);
    var
        SalesEntry: Record 99001473;
        SalesEntryTx: Record 99001472;
    begin
        LastRateVAT := 0;
        IF lfactor = 0 THEN EXIT;

        IF VATEntry.FINDFIRST THEN
            REPEAT

                IsOther := FALSE;

                IF CloseVATentry = 0 THEN
                    IF VATEntry.Closed THEN
                        CloseVATentry := VATEntry."Closed by Entry No.";

                IF VATEntry."Unrealized Amount" <> 0 THEN
                    VATEntry.Amount := VATEntry."Unrealized Amount";


                IF VATEntry."Unrealized Base" <> 0 THEN
                    VATEntry.Base := VATEntry."Unrealized Base";

                //GAS 1
                IF IsGroupVAT(VATEntry, 11) THEN BEGIN
                    VTOTAL[11] := VTOTAL[11] + ROUND(VATEntry.Base / lfactor, 0.001);
                END;

                //GAS 2
                IF IsGroupVAT(VATEntry, 12) THEN BEGIN
                    VTOTAL[12] := VTOTAL[12] + ROUND(VATEntry.Base / lfactor, 0.001);
                END;


                //TOURIT
                IF IsGroupVAT(VATEntry, 13) THEN BEGIN
                    VTOTAL[13] := VTOTAL[13] + ROUND(VATEntry.Base / lfactor, 0.001);
                END;

                //ALCOHOL
                IF IsGroupVAT(VATEntry, 14) THEN
                    VTOTAL[14] := VTOTAL[14] + ROUND(VATEntry.Base / lfactor, 0.001);

                // RET ISR
                IF IsGroupVAT(VATEntry, 16) THEN
                    VTOTAL[16] := VTOTAL[16] + ROUND(VATEntry.Base / lfactor, 0.001);

                // RET  VAT
                IF IsGroupVAT(VATEntry, 17) THEN
                    VTOTAL[17] := VTOTAL[17] + ROUND(VATEntry.Base / lfactor, 0.001);

                // RET NS
                IF IsGroupVAT(VATEntry, 18) THEN
                    VTOTAL[18] := VTOTAL[18] + ROUND(VATEntry.Base / lfactor, 0.001);

                // EXENCION
                IF IsGroupVAT(VATEntry, 19) THEN
                    VTOTAL[19] := VTOTAL[19] + ROUND(VATEntry.Base / lfactor, 0.001);

                // VAT VAT
                IF IsGroupVAT(VATEntry, 20) THEN BEGIN
                    VTOTAL[36] := VTOTAL[36] + ROUND(VATEntry.Amount / lfactor, 0.001);
                    VATEntry.Amount := 0;
                END;

                IF NOT IsOther THEN BEGIN
                    ///ASSET
                    IF IsGroupVAT(VATEntry, 1) THEN BEGIN
                        VTOTAL[1] := VTOTAL[1] + ROUND(VATEntry.Base / lfactor, 0.001);
                        VTOTAL[31] := VTOTAL[31] + ROUND(VATEntry.Amount / lfactor, 0.001);
                    END;

                    //SERVICE
                    IF IsGroupVAT(VATEntry, 2) THEN BEGIN
                        VTOTAL[2] := VTOTAL[2] + ROUND(VATEntry.Base / lfactor, 0.001);
                        VTOTAL[32] := VTOTAL[32] + ROUND(VATEntry.Amount / lfactor, 0.001);
                    END;

                    // ASSET X
                    IF IsGroupVAT(VATEntry, 3) THEN BEGIN
                        VTOTAL[3] := VTOTAL[3] + ROUND(VATEntry.Base / lfactor, 0.001);
                        VTOTAL[33] := VTOTAL[33] + ROUND(VATEntry.Amount / lfactor, 0.001);
                    END;

                    // SERVICE X
                    IF IsGroupVAT(VATEntry, 4) THEN BEGIN
                        VTOTAL[4] := VTOTAL[4] + ROUND(VATEntry.Base / lfactor, 0.001);
                        VTOTAL[34] := VTOTAL[34] + ROUND(VATEntry.Amount / lfactor, 0.001);
                    END;

                END; ///is not other

                // VAT Normal
                VTOTAL[20] := VTOTAL[20] + ROUND(VATEntry.Amount / lfactor, 0.001);

            UNTIL VATEntry.NEXT = 0;

        //TOTAL
        VTOTAL[21] := VTOTAL[1] + VTOTAL[2] + VTOTAL[3] + VTOTAL[4] + VTOTAL[11] + VTOTAL[12] + VTOTAL[13] + VTOTAL[14] + VTOTAL[20];
        //SUBTOTAL
        VTOTAL[22] := VTOTAL[1] + VTOTAL[2] + VTOTAL[3] + VTOTAL[4] + VTOTAL[11] + VTOTAL[12] + VTOTAL[13] + VTOTAL[14];
    end;

    procedure GetSerieCorr(pDocExt: Code[200]; var DocA: Text[100]; var DocB: Text[100]);
    var
        ExtDoc: Code[100];
        ii: Integer;
        jj: Integer;
    begin
        ExtDoc := pDocExt;

        ii := 0;
        jj := 0;

        REPEAT
            jj := jj + ii;
            ii := STRPOS(ExtDoc, '-');
            IF ii > 0 THEN ExtDoc := COPYSTR(ExtDoc, ii + 1);
        UNTIL ii = 0;

        IF jj = 0 THEN
            REPEAT
                jj := jj + ii;
                ii := STRPOS(ExtDoc, ' ');
                IF ii > 0 THEN ExtDoc := COPYSTR(ExtDoc, ii + 1);
            UNTIL ii = 0;


        IF jj > 0 THEN BEGIN
            DocA := COPYSTR(pDocExt, 1, jj - 1);
            DocB := COPYSTR(pDocExt, jj + 1);
        END ELSE BEGIN
            DocA := '';
            DocB := pDocExt;
            ;
        END;
    end;

    procedure RecVAT(var VatE: Record 254);
    begin

        IF VatE."VAT Calculation Type" = VatE."VAT Calculation Type"::"Full VAT" THEN BEGIN

            VatE.Base := VatE.Amount;
            VatE.Amount := 0;
        END;
    end;

    local procedure GenBookSales(pCompany: Text[50]);
    var
        SerieEstable: Text[10];
        ReadTrab: Boolean;
        VATadd: Boolean;
        RetailSetup: Record "LSC Retail Setup";
        dteTransaction: Record "FSN DTE Transaction Header";
        CustomForm: Text;
        CustomFormNo: text;
        LegalDocument: Record "Legal Ledger Entry";
        LegalSetup: Record "Legal Document";
        LegalSetup2: Record "Legal Document";
        mngRep: Codeunit IDSLOCfunctionStatement;
        dteTransactionOriginal: Record "FSN DTE Transaction Header";
        DTEAuthNumber, DTEInvoice, SignatureValidation : Text;
        Establishment, CustNRC, CustDUI : Code[20];
        percep: Decimal;
        transExpEntry: Record "LSC Trans. Inc./Exp. Entry";
    begin

        rLedgerSales.CHANGECOMPANY(pCompany);
        CustLedger2.CHANGECOMPANY(pCompany);
        CustLedger2.CHANGECOMPANY(pCompany);
        rCust.CHANGECOMPANY(pCompany);
        rSubType.CHANGECOMPANY(pCompany);
        rSales.CHANGECOMPANY(pCompany);
        rSalesSer.CHANGECOMPANY(pCompany);
        rSalesSerCr.CHANGECOMPANY(pCompany);
        rFinCharge.CHANGECOMPANY(pCompany);
        VATEntry.CHANGECOMPANY(pCompany);

        SourceCode.Get();
        RetailSetup.Get();
        rLedgerSales.RESET;
        rLedgerSales.SETCURRENTKEY("Posting Date", "Source Code");


        IF FilterDate <> '' THEN
            rStatementLegal.SETFILTER("Document Date", FilterDate)
        else begin
            //Procesar venta por fecha de documento no por fecha de registro
            //rLedgerSales.SETRANGE("Posting Date", FiltDate1,FiltDate2);
            rLedgerSales.SETRANGE("Document Date", FiltDate1, FiltDate2);
        end;
        rLedgerSales.SETFILTER("Source Code", '%1|%2|%3', SourceCode.Sales, SourceCode."Service Management", RetailSetup."Source Code");
        rLedgerSales.SETFILTER("Document Type", '%1|%2|%3',
        rLedgerSales."Document Type"::Invoice, rLedgerSales."Document Type"::"Credit Memo", rLedgerSales."Document Type"::"Finance Charge Memo");




        rStatementLegal.RESET;
        rStatementLegal.SETRANGE(Type, CurrentType);
        rStatementLegal.SETRANGE(Period, gPeriod);
        IF rStatementLegal.FINDLAST THEN
            gLineNoIni := rStatementLegal."Entry No.";

        gLineNo := gLineNoIni;
        ////filtro aditional

        IF DocNo <> '' THEN rLedgerSales.SETFILTER("Document No.", DocNo);

        IF FilterDate <> '' THEN rLedgerSales.SETFILTER("Document Date", FilterDate);

        wd.UPDATE(3, rLedgerSales.COUNT);

        lLine1 := 0;

        LedgerInforCode.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.");
        SaleslsRef.SETCURRENTKEY("Refund Receipt No.", "Store No.");

        subTypeDefa.SetRange(Default, true);
        subTypeDefa.SetRange("Destination Type", rSubType."Destination Type"::Customer);
        subTypeDefa.SetRange("Is Credit", false);
        IF not subTypeDefa.FindFirst() then
            Error('No existe sub tipo Default Factura de Venta')
        else
            gSubTypeInvDefa := subTypeDefa.Code;

        subTypeDefa.SetRange(Default, true);
        subTypeDefa.SetRange("Destination Type", rSubType."Destination Type"::Customer);
        subTypeDefa.SetRange("Is Credit", true);
        IF not subTypeDefa.FindFirst() then
            Error('No existe sub tipo Default Nota de Credito de Venta')
        else
            gSubTypeCMDefa := subTypeDefa.Code;

        VATEntry.RESET;
        VATEntry.SETCURRENTKEY("Document No.", "Posting Date", "Source Code");

        ShowDebug('SourCode', RetailSetup."Source Code", '');


        LegalSetup.SetRange("Use Percepcion", true);
        IF NOT LegalSetup.FindFirst() then LegalSetup.Init();


        LegalSetup2.SetRange("Use Retencion", true);
        IF NOT LegalSetup2.FindFirst() then LegalSetup2.Init();

        IF rLedgerSales.FIND('-') THEN
            REPEAT
                CustomForm := '';
                CustomFormNo := '';

                VATadd := FALSE;
                CloseVATentry := 0;
                Receipt := '';
                ReceiptRef := '';
                Terminal := '';
                lLine1 += 1;
                wd.UPDATE(2, lLine1);
                wd.UPDATE(1, 'Venta ' + rLedgerSales."Document No.");


                Skip := FALSE;
                CLEAR(ATOTAL);


                lfactor := 1;  //rLedgerSales."Original Currency Factor";
                stmp2 := 'E';
                rCust.GET(rLedgerSales."Customer No.");
                gNameClient := '';
                gVAT := '';
                DocExttmp := '';
                SerieEstable := '';
                Establishment := '';
                gDispositive := '';
                CLEAR(rSubTypeRef);
                rSubTypeRef.INIT;
                CLEAR(rSubType);
                rSubType.INIT;
                SkipEntry := FALSE;
                Identif1 := '';
                Identif2 := '';
                percep := 0;

                //IF rLedgerSales."Document No."='CAB-TCAB05-17052' THEN
                //MESSAGE('HOLA');

                ShowDebug('Doc', rLedgerSales."Document No.", '');

                IF rLedgerSales."Document Type" = rLedgerSales."Document Type"::Invoice THEN BEGIN
                    IF CustLedger2.GET(rLedgerSales."Closed by Entry No.") THEN
                        IF CustLedger2."Document Type" IN [CustLedger2."Document Type"::"Credit Memo"] THEN BEGIN
                            IF rCreditMemo.GET(CustLedger2."Document No.") THEN BEGIN
                                IF rSubTypeRef.GET(rCreditMemo."Sub Type") THEN
                                    IF rSubTypeRef.SubTypeRep = rSubTypeRef.SubTypeRep::Avoid THEN BEGIN
                                        stmp2 := 'A';
                                        lfactor := 0;
                                    END;
                                IF rCreditMemo."Sub Type" = '' THEN SkipEntry := FALSE;
                            END;
                        END;


                    CASE rLedgerSales."Source Code" OF
                        SourceCode.Sales:
                            BEGIN
                                rSales.GET(rLedgerSales."Document No.");
                                CustomForm := format(rSales."Customs Form");
                                CustomFormNo := Format(rSales."Customs Form No.");

                                IF rSales."Sell-to Customer No." <> rLedgerSales."Customer No." THEN rCust.GET(rSales."Sell-to Customer No.");

                                if rSales."Sub Type" = '' then rSales."Sub Type" := gSubTypeInvDefa;

                                IF NOT rSubType.GET(rSales."Sub Type") THEN ERROR(Text008, rLedgerSales."Document No.", rLedgerSales."Document Type");
                                IF pAName = pAName::Bill THEN
                                    gNameClient := rSales."Bill-to Name" + ' ' + rSales."Bill-to Name 2"
                                ELSE
                                    gNameClient := rSales."Sell-to Customer Name" + ' ' + rSales."Sell-to Customer Name 2";

                                gVAT := DELCHR(rSales."VAT Registration No.", '=', '-');
                                DocExttmp := rSales."External Document No.";
                                SerieEstable := rSubType.Establishment;

                                //JH02092024-1 Recuperar los datos de la factura electronica con la que se registro la venta
                                "DTEAuthNumber" := rSales."DTE AuthNumber";
                                "DTEInvoice" := rSales."DTE Invoice";
                                "SignatureValidation" := rSales."Signature Validation";
                                CustNRC := rCust."FSN NRC";
                                Establishment := rSales."Location Code";
                            END;
                        RetailSetup."Source Code":
                            BEGIN

                                if rLedgerSales."POS Store No." = '' then
                                    ExplodeDocNo(rLedgerSales."Document No.", rLedgerSales."POS Store No.", rLedgerSales."POS Terminal No.", rLedgerSales."POS Transaction No.");
                                IF NOT Store.GET(rLedgerSales."POS Store No.") then Store.Init();

                                rLedgerSales."Global Dimension 1 Code" := Store."Global Dimension 1 Code";

                                IF Salesls.GET(rLedgerSales."POS Store No.", rLedgerSales."POS Terminal No.", rLedgerSales."POS Transaction No.") THEN BEGIN

                                    if Salesls."Sub Type" = '' then Salesls."Sub Type" := gSubTypeInvDefa;

                                    if (Salesls."Legal Number" = '') and (Salesls."Legal Serie" = '') then begin
                                        Salesls."Legal Serie" := Salesls."POS Terminal No.";
                                        Salesls."Legal Number" := copystr(Salesls."Receipt No.", 11);
                                    end;

                                    IF NOT rSubType.GET(Salesls."Sub Type") THEN ERROR(Text008, rLedgerSales."Document No.", rLedgerSales."Document Type");

                                    IF rCust.GET(Salesls."Customer No.") THEN
                                        gNameClient := rCust.Name + ' ' + rCust."Name 2";


                                    /*
                                    LedgerInforCode.RESET;
                                    LedgerInforCode.SETRANGE("Store No.", Salesls."Store No.");
                                    LedgerInforCode.SETRANGE("POS Terminal No.", Salesls."POS Terminal No.");
                                    LedgerInforCode.SETRANGE("Transaction No.", Salesls."Transaction No.");
                                    LedgerInforCode.SETRANGE(Infocode, RetailSetup."Inforcode Exento");
                                    LSREXENTA := FALSE;
                                    IF LedgerInforCode.FINDFIRST THEN
                                        LSREXENTA := LedgerInforCode.Information = '01';

                                    LedgerInforCode.SETRANGE(Infocode, 'CLIENTE_HD');

                                    IF LedgerInforCode.FINDLAST THEN
                                        Identif2 := LedgerInforCode.Information;

                                    IF (rSubType."Prices Including VAT") AND (STRPOS(gNameClient, 'CLIENTE GEN') > 0) THEN BEGIN
                                        LedgerInforCode.SETRANGE(Infocode, 'CLIENTE_CO');
                                        IF LedgerInforCode.FINDLAST THEN
                                            gNameClient := LedgerInforCode.Information;

                                    END;
                                    */

                                    SaleslsRef.SETRANGE("Retrieved from Receipt No.", Salesls."Receipt No.");
                                    SaleslsRef.SETRANGE("Store No.", Salesls."Store No.");
                                    SaleslsRef.SETRANGE("Sale Is Return Sale", TRUE);
                                    SaleslsRef.SETFILTER("Net Amount", '>0');
                                    IF SaleslsRef.FINDFIRST THEN
                                        IF rSubTypeRef2.GET(SaleslsRef."Sub Type") THEN BEGIN
                                            IF (rSubTypeRef2.SubTypeRep = rSubTypeRef2.SubTypeRep::Avoid) THEN BEGIN
                                                stmp2 := 'A';
                                                lfactor := 1;
                                            END;
                                        END;

                                    POSterminal.GET(Salesls."POS Terminal No.");
                                    Terminal := POSterminal.Placement;

                                    gVAT := DELCHR(rCust."VAT Registration No.", '=', '-');
                                    DocExttmp := Salesls."Legal Serie" + '-' + Salesls."Legal Number";
                                    Receipt := Salesls."Receipt No.";
                                    ReceiptRef := Salesls."Retrieved from Receipt No.";
                                    gDispositive := Salesls."POS Terminal No.";

                                    /*
                                        IF Salesls."Additional Name" <> '' THEN
                                            VATadd := TRUE;

                                        IF Salesls."Additional Name" <> '' THEN
                                            gNameClient := Salesls."Additional Name";

                                        IF Salesls."Additional Name" <> '' THEN
                                            gVAT := DELCHR(Salesls."Additonal NIT", '=', '-');

                                        IF Salesls."Additional Name" <> '' THEN
                                            Identif2 := Salesls."Additonal DUI";

                                        IF Salesls."Additional Name" <> '' THEN
                                            rCust."State Inscription" := Salesls."Additonal Registro Fiscal";

                                    */
                                    transExpEntry.Reset();
                                    transExpEntry.SetRange("Receipt  No.", Salesls."Receipt No.");
                                    transExpEntry.SetRange("POS Terminal No.", Salesls."POS Terminal No.");
                                    transExpEntry.SetRange("Transaction No.", Salesls."Transaction No.");
                                    if transExpEntry.FindFirst() then
                                        percep := transExpEntry.Amount;
                                END;
                            END;
                    END; ///case source
                END;  //Invoice


                IF rLedgerSales."Document Type" = rLedgerSales."Document Type"::"Credit Memo" THEN BEGIN
                    IF CustLedger2.GET(rLedgerSales."Closed by Entry No.") THEN
                        IF CustLedger2."Document Type" IN [CustLedger2."Document Type"::Invoice] THEN BEGIN

                            IF CustLedger2."Source Code" = RetailSetup."Source Code" THEN BEGIN
                                rSales."Sub Type" := CustLedger2."Sub Type";
                                IF rSales."Sub Type" = '' THEN rSales."Sub Type" := gSubTypeInvDefa;
                                IF rSubTypeRef.GET(rSales."Sub Type") THEN
                                    IF rSubTypeRef.SubTypeRep = rSubTypeRef.SubTypeRep::Avoid THEN BEGIN
                                        stmp2 := 'A';
                                        lfactor := 0;
                                    END;
                            END ELSE
                                IF rSales.GET(CustLedger2."Document No.") THEN BEGIN
                                    IF rSales."Sub Type" = '' THEN rSales."Sub Type" := gSubTypeInvDefa;
                                    IF rSubTypeRef.GET(rSales."Sub Type") THEN
                                        IF rSubTypeRef.SubTypeRep = rSubTypeRef.SubTypeRep::Avoid THEN BEGIN
                                            stmp2 := 'A';
                                            lfactor := 0;
                                        END;
                                    IF rSales."Sub Type" = '' THEN SkipEntry := FALSE;
                                END;
                        END;

                    CASE rLedgerSales."Source Code" OF
                        SourceCode.Sales:
                            BEGIN
                                rCreditMemo.GET(rLedgerSales."Document No.");
                                IF rCreditMemo."Sell-to Customer No." <> rLedgerSales."Customer No." THEN rCust.GET(rSales."Sell-to Customer No.");

                                if rCreditMemo."Sub Type" = '' then rCreditMemo."Sub Type" := gSubTypeCMDefa;
                                IF NOT rSubType.GET(rCreditMemo."Sub Type") THEN ERROR(Text008, rLedgerSales."Document No.", rLedgerSales."Document Type");
                                IF pAName = pAName::Bill THEN
                                    gNameClient := rCreditMemo."Bill-to Name" + ' ' + rCreditMemo."Bill-to Name 2"
                                ELSE
                                    gNameClient := rCreditMemo."Sell-to Customer Name" + ' ' + rCreditMemo."Sell-to Customer Name 2";
                                gVAT := DELCHR(rCreditMemo."VAT Registration No.", '=', '-');
                                DocExttmp := rCreditMemo."External Document No.";
                                SerieEstable := rSubType.Establishment;
                                //JH3082024 Agregar NRC y No Identificacion segun transacción
                                CustNRC := rCust."FSN NRC";
                                Establishment := rCreditMemo."Location Code";
                            END;

                        RetailSetup."Source Code":
                            BEGIN

                                if rLedgerSales."POS Store No." = '' then
                                    ExplodeDocNo(rLedgerSales."Document No.", rLedgerSales."POS Store No.", rLedgerSales."POS Terminal No.", rLedgerSales."POS Transaction No.");

                                Store.GET(rLedgerSales."POS Store No.");
                                rLedgerSales."Global Dimension 1 Code" := Store."Global Dimension 1 Code";

                                IF Salesls.GET(rLedgerSales."POS Store No.", rLedgerSales."POS Terminal No.", rLedgerSales."POS Transaction No.") THEN BEGIN

                                    if (Salesls."Legal Number" = '') and (Salesls."Legal Serie" = '') then begin
                                        Salesls."Legal Serie" := Salesls."POS Terminal No.";
                                        Salesls."Legal Number" := copystr(Salesls."Receipt No.", 11);
                                    end;

                                    if Salesls."Sub Type" = '' then Salesls."Sub Type" := gSubTypeCMDefa;
                                    IF NOT rSubType.GET(Salesls."Sub Type") THEN BEGIN
                                        stmp2 := 'A';
                                        rSubType.INIT;
                                    END;

                                    IF rCust.GET(Salesls."Customer No.") THEN
                                        gNameClient := rCust.Name + ' ' + rCust."Name 2";

                                    /*
                                                     LedgerInforCode.RESET;
                                                     LedgerInforCode.SETRANGE("Store No.", Salesls."Store No.");
                                                     LedgerInforCode.SETRANGE("POS Terminal No.", Salesls."POS Terminal No.");
                                                     LedgerInforCode.SETRANGE("Transaction No.", Salesls."Transaction No.");
                                                     LedgerInforCode.SETRANGE(Infocode, RetailSetup."Inforcode Exento");
                                                     LSREXENTA := FALSE;
                                                     IF LedgerInforCode.FINDFIRST THEN
                                                         LSREXENTA := LedgerInforCode.Information = '01';

                                                     LedgerInforCode.SETRANGE(Infocode, 'CLIENTE_HD');
                                                     IF LedgerInforCode.FINDLAST THEN
                                                         Identif2 := LedgerInforCode.Information;

                                                     LedgerInforCode.SETRANGE(Infocode, 'CLIENTE_CO');
                                                     IF LedgerInforCode.FINDLAST THEN
                                                         IF STRPOS(gNameClient, 'CLIENTE GEN') > 0 THEN
                                                             gNameClient := LedgerInforCode.Information;

                                             */
                                    POSterminal.GET(Salesls."POS Terminal No.");
                                    Terminal := POSterminal.Placement;
                                    gVAT := DELCHR(rCust."VAT Registration No.", '=', '-');
                                    DocExttmp := Salesls."Legal Serie" + '-' + Salesls."Legal Number";
                                    Receipt := Salesls."Receipt No.";
                                    ReceiptRef := Salesls."Retrieved from Receipt No.";
                                    gDispositive := Salesls."POS Terminal No.";


                                    /// // IF Salesls."Additional Name" != '' THEN
                                    //VATadd := TRUE;

                                    // IF Salesls."Additional Name" <> '' THEN
                                    //     gNameClient := Salesls."Additional Name";

                                    // IF Salesls."Additional Name" <> '' THEN
                                    //     gVAT := DELCHR(Salesls."Additonal NIT", '=', '-');

                                    //IF Salesls."Additional Name" <> '' THEN
                                    //    Identif2 := Salesls."Additonal DUI";

                                    //IF Salesls."Additional Name" <> '' THEN
                                    //    rCust."State Inscription" := Salesls."Additonal Registro Fiscal";

                                    //IF rSubTypeRef2.GET(Salesls."Sub Type") THEN
                                    //    IF rSubTypeRef2.SubTypeRep = rSubTypeRef.SubTypeRep::Avoid THEN
                                    //       ;// SkipEntry:=TRUE;

                                    //JH3082024 Agregar NRC y No Identificacion segun transacción
                                    CustNRC := Salesls."FSN NRC";
                                    CustDUI := Salesls."FSN DUI";
                                    if CustDUI = '' then
                                        CustDUI := Salesls."FSN Foreign document";

                                    Establishment := rLedgerSales."POS Store No.";
                                END;
                            END;
                    END; //case
                END;  //Credit Memo

                ///CARGOS FINANCIEROS
                IF rLedgerSales."Document Type" = rLedgerSales."Document Type"::"Finance Charge Memo" THEN BEGIN
                    IF CustLedger2.GET(rLedgerSales."Closed by Entry No.") THEN
                        IF CustLedger2."Document Type" IN [CustLedger2."Document Type"::"Credit Memo"] THEN BEGIN
                            IF rCreditMemo.GET(CustLedger2."Document No.") THEN BEGIN
                                IF rSubType.GET(rCreditMemo."Sub Type") THEN
                                    IF rSubType.SubTypeRep = rSubType.SubTypeRep::Avoid THEN BEGIN
                                        stmp2 := 'A';
                                        lfactor := 0;
                                    END;
                            END;
                        END;


                    CASE rLedgerSales."Source Code" OF
                        SourceCode.Sales:
                            BEGIN
                                rFinCharge.GET(rLedgerSales."Document No.");
                                IF NOT rSubType.GET(rFinCharge."Sub Type") THEN ERROR(Text008, rLedgerSales."Document No.", rLedgerSales."Document Type");
                                gNameClient := rFinCharge.Name + ' ' + rFinCharge."Name 2";
                                gVAT := DELCHR(rFinCharge."VAT Registration No.", '=', '-');
                                DocExttmp := rFinCharge."External Document No.";
                                SerieEstable := rSubType.Establishment;
                            END;

                    END; ///case source
                END;  //fin charge

                ///
                IF rLedgerSales."Payment Method Code" = 'ANUL' THEN BEGIN
                    stmp2 := 'A';
                    lfactor := 0;
                END;


                IF NOT rSubType."Include Ledger" THEN SkipEntry := TRUE;

                ShowDebug('Doc', rLedgerSales."Document No.", ' Skip ' + Format(SkipEntry));

                IF NOT (SkipEntry) THEN BEGIN
                    IF NOT VATadd THEN BEGIN
                        IF gVAT = '' THEN gVAT := rCust."VAT Registration No.";
                        IF gVAT = '' THEN gVAT := '0';
                        IF STRLEN(gVAT) < 3 THEN gVAT := rCust."VAT Registration No.";
                    END;
                    gVAT := DELCHR(gVAT, '=', '-');

                    IF (gNameClient = '') OR (gNameClient = ' ') THEN gNameClient := rCust.Name + ' ' + rCust."Name 2";

                    IF (rSubType.SubTypeRep = rSubType.SubTypeRep::Standar) OR (rSubType.SubTypeRep = rSubType.SubTypeRep::"Inv-R") THEN BEGIN

                        IF rCust."Country/Region Code" = '' THEN rCust."Country/Region Code" := rCompany."Country/Region Code";
                        IF (rCompany."Country/Region Code" <> rCust."Country/Region Code") THEN
                            IF rCust."Country/Region Code" IN ['GT', 'HN', 'SV', 'NI', 'CR', 'PA'] THEN
                                rSubType.SubTypeRep := rSubType.SubTypeRep::"Inv-R"
                            ELSE
                                rSubType.SubTypeRep := rSubType.SubTypeRep::"Inv-I";
                    END;

                    IF COPYSTR(rLedgerSales."External Document No.", 1, 3) = 'VTA' THEN
                        rLedgerSales."External Document No." := COPYSTR(rLedgerSales.Description, 7);

                    stmp4 := 'S0';
                    IF DocExttmp = '' THEN DocExttmp := rLedgerSales."External Document No.";

                    SplitDocExt(DocExttmp, stmp4, stmp5, tmpFolioYY);


                    rStamentVAT.INIT;
                    gLineNo := gLineNo + 1;
                    iLineFolio += 1;

                    // agregar los datos del DTE
                    if Salesls."Sale Is Return Sale" then begin
                        SaleslsOriginal.Reset();
                        SaleslsOriginal.SetRange("Receipt No.", Salesls."Retrieved from Receipt No.");
                        SaleslsOriginal.SetRange("Customer No.", Salesls."Customer No.");
                        if SaleslsOriginal.FindFirst() then begin
                            dteTransactionOriginal.Reset();
                            dteTransactionOriginal.SetRange("Store No.", SaleslsOriginal."Store No.");
                            dteTransactionOriginal.SetRange("POS Terminal No.", SaleslsOriginal."POS Terminal No.");
                            dteTransactionOriginal.SetRange("Transaction No.", SaleslsOriginal."Transaction No.");
                            if dteTransactionOriginal.FindFirst() then begin
                                "DTEAuthNumber" := dteTransactionOriginal."DTE AuthNumber";
                                "DTEInvoice" := dteTransactionOriginal."DTE Invoice";
                                "SignatureValidation" := dteTransactionOriginal."Signature Validation";
                                Establishment := rLedgerSales."POS Store No.";
                            end;
                        end;
                    end else begin
                        dteTransaction.SetRange("Store No.", rLedgerSales."POS Store No.");
                        dteTransaction.SetRange("POS Terminal No.", rLedgerSales."POS Terminal No.");
                        dteTransaction.SetRange("Transaction No.", rLedgerSales."POS Transaction No.");
                        if dteTransaction.FindFirst() then begin
                            "DTEAuthNumber" := dteTransaction."DTE AuthNumber";
                            "DTEInvoice" := dteTransaction."DTE Invoice";
                            "SignatureValidation" := dteTransaction."Signature Validation";
                        end;
                    end;




                    IF stmp2 = 'A' THEN gNameClient := gNameClient + ' ANULADA';

                    rStamentVAT.Period := gPeriod;
                    //nota debe remplaza document type por ENU JOUNRBAK DOCUMENT
                    rStamentVAT."Document Type" := rLedgerSales."Document Type";
                    rStamentVAT."Entry No." := gLineNo;
                    rStamentVAT."Sub Type" := rSubType.Code;
                    rStamentVAT."Rep SubType" := rSubType.SubTypeRep;

                    rStamentVAT."Document No." := rLedgerSales."Document No.";
                    rStamentVAT."Serie Code" := SeriePre;
                    rStamentVAT."Legal Document" := rSubType."Transaction Doc.";
                    rStamentVAT."Legal Transaction Type" := rSubType."Transaction Type";
                    rStamentVAT."Legal State" := stmp2;
                    rStamentVAT.Terminal := Terminal;
                    rStamentVAT."Region Country" := rCust."Country/Region Code";
                    //JH24072024-1 Se asigna el establecimiento según Store No. LedgerSales
                    //rStamentVAT.Establishment := SerieEstable;
                    rStamentVAT.Establishment := Establishment;
                    //JH27082024-1 Se asigna la termina según venta
                    rStamentVAT.Terminal := rLedgerSales."POS Terminal No.";

                    //JH02082024-2 Recuperar los datos de la factura electronica con la que se registro la compra
                    rStamentVAT."DTE AuthNumber" := DTEAuthNumber;
                    rStamentVAT."DTE Invoice" := DTEInvoice;
                    rStamentVAT."Signature Validation" := SignatureValidation;

                    //JH07112024
                    rStamentVAT.Perception := percep;

                    rStamentVAT.Type := 1;  //ventas
                                            //rStamentVAT."Legal Document":=sdoc;
                    rStamentVAT."Legal Serie" := stmp4;
                    rStamentVAT."Legal No." := stmp5;

                    IF iLineFolio > gPageFolio THEN BEGIN
                        iFolio += 1;
                        iLineFolio := 1;
                    END;

                    rStamentVAT.Folio := iFolio;
                    rStamentVAT."Line No." := gLineNo - (iFolio - 1) * gPageFolio;


                    rStamentVAT."Document Date" := rLedgerSales."Document Date";
                    rStamentVAT."Posting Date" := rLedgerSales."Posting Date";
                    rStamentVAT.NIT := gVAT;
                    //rStamentVAT.NCR:=rCust."CURP No.";
                    rStamentVAT.NRC := CustNRC; //11AGO2020
                    rStamentVAT."Customs Form" := CustomForm;
                    rStamentVAT."Customs Form No." := CustomFormNo;


                    rStamentVAT.Name := gNameClient;
                    rStamentVAT."Custom Region" := lRegion;
                    rStamentVAT."Identif No." := CustDUI;
                    rStamentVAT."Identif Order" := Identif1;

                    VATEntry.SETRANGE("Document No.", rLedgerSales."Document No.");
                    VATEntry.SETRANGE(Type, VATEntry.Type::Sale);
                    VATEntry.SETRANGE("Source Code", rLedgerSales."Source Code");
                    VATEntry.SETRANGE("Posting Date", rLedgerSales."Posting Date");
                    VATEntry.SETRANGE("POS Store No.", rLedgerSales."POS Store No.");
                    VATEntry.SETRANGE("POS Terminal No.", rLedgerSales."POS Terminal No.");
                    VATEntry.SETRANGE("POS Transaction No.", rLedgerSales."POS Transaction No.");

                    ReadTrab := false;
                    IF (rLedgerSales."Source Code" = RetailSetup."Source Code") AND (VATEntry.Count = 0) then
                        ReadTrab := true;

                    CLEAR(ATOTAL);




                    IF ReadTrab THEN BEGIN
                        ATOTAL[1] := Salesls."Net Amount" * -1;
                        ATOTAL[31] := Salesls."Gross Amount" * -1;
                        ATOTAL[22] := Salesls."Net Amount" * -1;  //subtotal
                        ATOTAL[20] := (Salesls."Gross Amount" - Salesls."Net Amount") * -1;//vat
                        ATOTAL[21] := Salesls."Gross Amount" * -1 + ATOTAL[17];   //totsl;
                    END
                    ELSE
                        GetValueVAT(VATEntry, ATOTAL, -lfactor, sdoc);

                    IF (rLedgerSales."Source Code" = RetailSetup."Source Code") then
                        IF (LegalSetup.Code <> '') OR (LegalSetup2.Code <> '') then begin

                            mngRep.ReplicaWhtDocumentLegal(Salesls);
                            LegalDocument.RESET;
                            LegalDocument.SetFilter("Line No.", '>0');
                            LegalDocument.SETRANGE("Document Type", LegalDocument."Document Type"::"POS Invoice");
                            LegalDocument.SETFILTER("No.", rLedgerSales."Document No.");
                            LegalDocument.SetRange("Legal Doc Code", LegalSetup.Code);
                            if LegalDocument.FindFirst() then
                                ATOTAL[17] := LegalDocument."Amount Including VAT";

                            LegalDocument.SetRange("Legal Doc Code", LegalSetup2.Code);
                            if LegalDocument.FindFirst() then
                                ATOTAL[16] := LegalDocument."Amount Including VAT";
                        end;




                    CASE rSubType.SubTypeRep OF
                        rSubType.SubTypeRep::Standar, rSubType.SubTypeRep::" ":
                            BEGIN
                                rStamentVAT."Base Affect Goods" := ATOTAL[1];
                                rStamentVAT."Base Affect Service" := ATOTAL[2];
                                rStamentVAT."Excent Goods" := ATOTAL[3];
                                rStamentVAT."Excent Service" := ATOTAL[4];
                                rStamentVAT."VAT Affect Goods" := ATOTAL[31];
                                rStamentVAT."VAT Affect Service" := ATOTAL[32];
                                stmp1 := 'L';
                            END;

                        rSubType.SubTypeRep::"Inv-R":
                            BEGIN
                                rStamentVAT."Base Internac Goods" := ATOTAL[1];
                                rStamentVAT."Base Internac Service" := ATOTAL[2];
                                rStamentVAT."Excent Internac Goods" := ATOTAL[3];
                                rStamentVAT."Excent Internac Service" := ATOTAL[4];
                                rStamentVAT."VAT Internac Goods" := ATOTAL[31];
                                rStamentVAT."VAT Internac Service" := ATOTAL[32];
                                stmp1 := 'R';
                            END;

                        rSubType.SubTypeRep::"Inv-I":
                            BEGIN
                                rStamentVAT."Base Inter Goods" := ATOTAL[1];
                                rStamentVAT."Base Inter Service" := ATOTAL[2];
                                rStamentVAT."Excent Inter Goods" := ATOTAL[3];
                                rStamentVAT."Excent Inter Service" := ATOTAL[4];
                                rStamentVAT."VAT Inter Goods" := ATOTAL[31];
                                rStamentVAT."VAT Inter Service" := ATOTAL[32];
                                stmp1 := 'E';
                            END;


                        rSubType.SubTypeRep::"Small Contributo":
                            BEGIN
                                rStamentVAT."Small Contributor Goods" := ATOTAL[1] + ATOTAL[31] + ATOTAL[3] + ATOTAL[33];
                                rStamentVAT."Small Contributor Service" := ATOTAL[2] + ATOTAL[32] + ATOTAL[4] + ATOTAL[34];
                                ATOTAL[22] := ATOTAL[21];
                            END;

                        rSubType.SubTypeRep::"Inv-Spec":
                            BEGIN
                                rStamentVAT."Base Special Invoice Goods" := ATOTAL[1] + ATOTAL[31] + ATOTAL[3] + ATOTAL[33];
                                rStamentVAT."Base Special Invoice  Service" := ATOTAL[2] + ATOTAL[32] + ATOTAL[4] + ATOTAL[34];
                                rStamentVAT."VAT Special Goods" := ATOTAL[31];
                                rStamentVAT."VAT Special Service" := ATOTAL[32];
                                ATOTAL[22] := ATOTAL[21];
                            END;

                    END;


                    IF IsCompany3rd THEN BEGIN
                        rStamentVAT."Base 3rd Goods" := ATOTAL[1];
                        rStamentVAT."Base 3rd Service" := ATOTAL[2];
                        rStamentVAT."Excent 3rd Goods" := ATOTAL[3];
                        rStamentVAT."Excent 3rd Service" := ATOTAL[4];
                        rStamentVAT."VAT 3rd" := ATOTAL[20];
                        rStamentVAT."Ret VAT 3rd" := ATOTAL[17];
                        IF rSubType.SubTypeRep = rSubType.SubTypeRep::"Inv-Spec" THEN BEGIN
                            rStamentVAT."Base 3rd Goods" := ATOTAL[1] + ATOTAL[31];
                            rStamentVAT."Base 3rd Service" := ATOTAL[2] + ATOTAL[32];
                            rStamentVAT."Excent 3rd Goods" := ATOTAL[3] + ATOTAL[33];
                            rStamentVAT."Excent 3rd Service" := ATOTAL[4] + ATOTAL[34];
                            rStamentVAT."VAT 3rd" := ATOTAL[20];
                            rStamentVAT."Ret VAT 3rd" := ATOTAL[17];
                            ATOTAL[22] := ATOTAL[21];  //subtotal = total
                        END;
                        ATOTAL[1] := 0;
                        ATOTAL[2] := 0;
                        ATOTAL[3] := 0;
                        ATOTAL[4] := 0
                    END;


                    IF lfactor = 0 THEN CLEAR(ATOTAL);

                    rStamentVAT."Gas 1" := ATOTAL[11];
                    rStamentVAT."Gas 2" := ATOTAL[12];
                    rStamentVAT.Tourist := ATOTAL[13];
                    rStamentVAT.Alcohol := ATOTAL[14];

                    rStamentVAT."Ret Inc" := ATOTAL[16];
                    rStamentVAT."Ret VAT" := ATOTAL[17];
                    rStamentVAT."Ret NS" := ATOTAL[18];
                    rStamentVAT.Exencion := ATOTAL[19];

                    rStamentVAT."Sub Total" := ATOTAL[22];
                    rStamentVAT.VAT := ATOTAL[20];
                    rStamentVAT.Total := ATOTAL[21];


                    IF rSubTypeRef.Code = '' THEN
                        rStamentVAT."Prices Including VAT" := rSubType."Prices Including VAT"
                    ELSE
                        rStamentVAT."Prices Including VAT" := rSubTypeRef."Prices Including VAT";

                    rStamentVAT.Dispositive := gDispositive;
                    IF pAName = pAName::Bill THEN
                        rStamentVAT."Customer No." := rLedgerSales."Customer No."
                    ELSE
                        rStamentVAT."Customer No." := rCust."No.";

                    //IF rStamentVAT."Document No."= '001717' THEN
                    // MESSAGE('Documento %1 Price incl vat %2',rStamentVAT."Document No.",rStamentVAT."Prices Including VAT");

                    rStamentVAT."Shortcut Dimension 1 Code" := rLedgerSales."Global Dimension 1 Code";
                    rStamentVAT."Shortcut Dimension 2 Code" := rLedgerSales."Global Dimension 2 Code";
                    rStamentVAT.Receipt := Receipt;
                    rStamentVAT."Receipt Refound" := ReceiptRef;
                    rStamentVAT."Source Code" := rLedgerSales."Source Code";

                    IF CloseVATentry = 0 THEN
                        rStamentVAT.INSERT
                    ELSE BEGIN
                        rStatementLegal.SETRANGE(Type, CurrentType);
                        rStatementLegal.SETRANGE(Period, gPeriod);
                        rStatementLegal.SETRANGE("Closed by Entry No.", CloseVATentry);
                        rStamentVAT."Closed by Entry No." := CloseVATentry;
                        IF NOT rStatementLegal.FINDFIRST THEN
                            rStamentVAT.INSERT
                        ELSE
                            gLineNo -= 1;
                    END;


                END;  //SKIPENTRY
            UNTIL (rLedgerSales.NEXT = 0);



        /// retencion y percepciones venta LS
        /*
                LegalDocument.RESET;
                LegalDocument.SetFilter("Line No.",'>0');
                LegalDocument.SETRANGE("Posting Date", FiltDate1, FiltDate2);
                IF DocNo <> '' THEN
                    LegalDocument.SETFILTER("No.", DocNo);


                wd.UPDATE(3, LegalDocument.COUNT);
                if LegalDocument.FindFirst() then
                    repeat
                        stmp2 := '';
                        SkipEntry := false;
                        //if WithholdCode.Get(ComputeWht."Withholding Tax Code") then
                        //    SkipEntry := not WithholdCode."Include Ledger";

                       // if not SkipEntry then
                       //     SkipEntry := computeWht."Close Apply No." < 0;

                        if NOT SkipEntry then begin

                            rLedgerPurch.SetRange("Posting Date", computeWht."Posting Date");
                            rLedgerPurch.SetRange("Document No.", computeWht."Document No.");
                            if not rLedgerPurch.FindFirst() then rLedgerPurch.Init();

                            VATledgerREf.SetRange("Document No.", rLedgerPurch."Document No.");
                            VATledgerREf.SetRange(Period, gPeriod);
                            VATledgerREf.SetRange(TYPE, 0);

                            IF NOT VATledgerREf.FindFirst() then VATledgerREf.INIT;

                            rVendor.Get(ComputeWht."Vendor No.");
                            iLineFolio += 1;
                            gNameClient := rLedgerPurch."Vendor Name";
                            IF stmp2 = 'A' THEN gNameClient := 'ANULADA';
                            rStamentVAT.INIT;
                            rStamentVAT.NIT := VATledgerREf.NIT;
                            rStamentVAT.NCR := VATledgerREf.NCR;
                            rStamentVAT.Name := VATledgerREf.Name;
                            rStamentVAT."Document Date" := VATledgerREf."Document Date";
                            rStamentVAT."Identif No." := VATledgerREf."Identif No.";
                            rStamentVAT."Identif Order" := VATledgerREf."Identif Order";
                            rStamentVAT.Period := gPeriod;
                            rStamentVAT."Document Type" := rStamentVAT."Document Type"::"Withholding Tax";
                            rStamentVAT."Entry No." := gLineNo;
                            // rStamentVAT."Sub Type" := rSubType.Code;
                            // rStamentVAT."Rep SubType" := rSubType.SubTypeRep;

                            rStamentVAT."Document No." := computeWht."Document No.";
                            // rStamentVAT."Serie Code" := SeriePre;
                            // rStamentVAT."Legal Document" := rSubType."Transaction Doc.";
                            // rStamentVAT."Legal Transaction Type" := rSubType."Transaction Type";
                            //  rStamentVAT."Legal State" := stmp2;

                            // IF SerieEstable = '' THEN SerieEstable := rSubType.Establishment;
                            //  rStamentVAT.Establishment := SerieEstable;


                            rStamentVAT.Type := 0;  //compras
                                                    //rStamentVAT."Legal Document":=sdoc;
                                                    //rStamentVAT."Legal Serie" := stmp4;
                            rStamentVAT."Legal No." := computeWht."Withhold ISR No.";

                            IF iLineFolio > gPageFolio THEN BEGIN
                                iFolio += 1;
                                iLineFolio := 1;
                            END;

                            rStamentVAT.Folio := iFolio;
                            rStamentVAT."Line No." := gLineNo - (iFolio - 1) * gPageFolio;

                            rStamentVAT."Document Date" := computeWht."Document Date";
                            rStamentVAT."Posting Date" := computeWht."Posting Date";
                            rStamentVAT.NIT := rVendor."VAT Registration No.";
                            rStamentVAT.NCR := rVendor."CURP No.";
                            rStamentVAT.Name := gNameClient;
                            // rStamentVAT."Custom Region" := lRegion;
                            // rStamentVAT."Customs Form" := CustomForm;
                            rStamentVAT."Customer No." := rLedgerPurch."Vendor No.";
                            CLEAR(ATOTAL);
                            //   rStamentVAT."Prices Including VAT" := rSubType."Prices Including VAT";
                            rStamentVAT."Shortcut Dimension 1 Code" := rLedgerPurch."Global Dimension 1 Code";
                            rStamentVAT."Shortcut Dimension 2 Code" := rLedgerPurch."Global Dimension 2 Code";

                            //LegalLedger.SetRange("Document Type", rLedgerPurch."Document Type");
                            LegalLedger.SetRange("No.", rLedgerPurch."Document No.");

                            if ComputeWht."Withholding Tax Amount ISR" > 0 then begin
                                rStamentVAT."Withholding No." := '';
                                ATOTAL[16] := -ComputeWht."Withholding Tax Amount ISR";
                                ATOTAL[17] := 0;
                                ComputeWht.CalcFields("Withhold ISR No.", "Withhold Tax No.");

                                LegalDoc.SetRange(Type, LegalDoc.Type::ISR);
                                IF LegalDoc.FindFirst() Then begin

                                    LegalLedger.SetRange("Legal Doc Code", LegalDoc.Code);
                                    if LegalLedger.FindFirst() then
                                        rStamentVAT."Withholding No." := LegalLedger.Number;
                                end;


                                gLineNo := gLineNo + 1;

                                if rStamentVAT."Withholding No." = '' then
                                    rStamentVAT."Withholding No." := ComputeWht."Withhold ISR No.";
                                rStamentVAT."Entry No." := gLineNo;
                                rStamentVAT."Ret Inc" := ATOTAL[16];
                                rStamentVAT."Ret VAT" := ATOTAL[17];
                                rStamentVAT."Ret NS" := ATOTAL[18];
                                rStamentVAT."Sub Total" := ATOTAL[22];
                                rStamentVAT."Withholding Base" := ComputeWht."Taxable Base ISR";
                                rStamentVAT.VAT := ATOTAL[20];
                                rStamentVAT.Total := ATOTAL[21];
                                rStamentVAT.Insert();
                            end;

                            if ComputeWht."Withholding Tax Amount VAT" > 0 then begin
                                ATOTAL[17] := -ComputeWht."Withholding Tax Amount VAT";
                                ATOTAL[16] := 0;
                                rStamentVAT."Withholding No." := '';

                                LegalDoc.SetRange(Type, LegalDoc.Type::VAT);
                                IF LegalDoc.FindFirst() Then begin
                                    LegalLedger.SetRange("Legal Doc Code", LegalDoc.Code);
                                    if LegalLedger.FindFirst() then
                                        rStamentVAT."Withholding No." := LegalLedger.Number;
                                end;
                                gLineNo := gLineNo + 1;
                                if rStamentVAT."Withholding No." = '' then
                                    rStamentVAT."Withholding No." := ComputeWht."Withhold Tax No.";
                                rStamentVAT."Entry No." := gLineNo;
                                rStamentVAT."Ret Inc" := ATOTAL[16];
                                rStamentVAT."Ret VAT" := ATOTAL[17];
                                rStamentVAT."Ret NS" := ATOTAL[18];
                                rStamentVAT."Sub Total" := ATOTAL[22];
                                rStamentVAT.VAT := ATOTAL[20];
                                rStamentVAT.Total := ATOTAL[21];
                                rStamentVAT."Withholding Base" := ComputeWht."Taxable Base VAT";
                                rStamentVAT.Insert();
                            end;



                        end;

                    until LegalDocument.Next() = 0;
                    */

    end;

    local procedure GenBookPurchase(pCompany: Text[50]);
    var
        rCreditMemoPur: Record 124;
        rPuch: Record 122;
        DocLegal: Record "Legal Ledger Entry";
        tmpLd: Text;
        ComputeWithholdingTax: Record "Computed Withholding Tax";
        ComputeWht: Record "Computed Withholding Tax";
        WithholdCode: Record "Withhold Code";
        LegalLedger: Record "Legal Ledger Entry";
        LegalDoc: Record "Legal Document";
        VATledgerREf: Record "VAT Ledger";
        UniqueDocNo: Text;
        DTEAuthNumber, DTEInvoice, SignatureValidation : Text;

    begin

        //******************************************************** PURCHASE AND CREDIT MEMO

        rLedgerPurch.CHANGECOMPANY(pCompany);
        VenLedger2.CHANGECOMPANY(pCompany);
        rVendor.CHANGECOMPANY(pCompany);
        rSubType.CHANGECOMPANY(pCompany);
        rPurch.CHANGECOMPANY(pCompany);
        rCreditMemoPur.CHANGECOMPANY(pCompany);
        ///  solo uno  rStamentVAT.CHANGECOMPANY(pCompany);
        //// rStatementLegal.CHANGECOMPANY(pCompany);
        rFinCharge.CHANGECOMPANY(pCompany);
        VATEntry.CHANGECOMPANY(pCompany);
        // THE same company rLoc.CHANGECOMPANY(pCompany)';


        rStatementLegal.RESET;
        rStatementLegal.SETRANGE(Type, CurrentType);
        rStatementLegal.SETRANGE(Period, gPeriod);
        IF rStatementLegal.FINDLAST THEN
            gLineNoIni := rStatementLegal."Entry No.";

        gLineNo := gLineNoIni;


        iFolio := gFolio;
        iLineFolio := 0;


        subTypeDefa.SetRange(Default, true);
        subTypeDefa.SetRange("Destination Type", rSubType."Destination Type"::Vendor);
        subTypeDefa.SetRange("Is Credit", false);
        IF not subTypeDefa.FindFirst() then
            Error('No existe sub tipo Default Factura de Compra')
        else
            gSubTypeInvDefa := subTypeDefa.Code;

        subTypeDefa.SetRange(Default, true);
        subTypeDefa.SetRange("Destination Type", rSubType."Destination Type"::Vendor);
        subTypeDefa.SetRange("Is Credit", true);
        IF not subTypeDefa.FindFirst() then
            Error('No existe sub tipo Default Nota de Credito de Compra')
        else
            gSubTypeCMDefa := subTypeDefa.Code;


        IF FilterDate <> '' THEN
            rStatementLegal.SETFILTER("Document Date", FilterDate)
        else begin
            //Imprime las COMPRS
            //Procesar venta por fecha de documento no por fecha de registro
            //rLedgerSales.SETRANGE("Posting Date", FiltDate1,FiltDate2);
            rLedgerPurch.SETRANGE("Document Date", FiltDate1, FiltDate2);
        end;
        rLedgerPurch.SETFILTER("Document Type", '%1|%2|%3',
        rLedgerPurch."Document Type"::Invoice, rLedgerPurch."Document Type"::"Credit Memo", rLedgerPurch."Document Type"::"Finance Charge Memo");

        IF FilterDate <> '' THEN
            rLedgerPurch.SETFILTER("Document Date", FilterDate);

        IF DocNo <> '' THEN rLedgerPurch.SETFILTER("Document No.", DocNo);

        wd.UPDATE(3, rLedgerPurch.COUNT);

        lLine1 := 0;
        IF rLedgerPurch.FINDFIRST THEN
            REPEAT
                UniqueDocNo := '';
                AmountPoliza := 0;
                CloseVATentry := 0;

                wd.UPDATE(2, lLine1);
                wd.UPDATE(1, 'Compra' + rLedgerPurch."Document No.");


                Skip := FALSE;
                CLEAR(ATOTAL);


                lfactor := 1;  //rLedgerSales."Original Currency Factor";
                stmp1 := 'L';
                stmp2 := 'E';
                sdoc := 'XX';
                SeriePre := '';
                rVendor.GET(rLedgerPurch."Vendor No.");
                gNameClient := '';
                gVAT := '';
                DocExttmp := '';
                CLEAR(rSubTypeRef);
                rSubTypeRef.INIT;
                Identif1 := '';
                Identif2 := '';

                //IF rLedgerPurch."Document No."='CAB-TCAB05-17052' THEN
                //MESSAGE('HOLA');
                //DocExttmp:=rLedgerPurch."External Document No.";



                IF rLedgerPurch."Document Type" = rLedgerPurch."Document Type"::Invoice THEN BEGIN
                    IF rPurch.GET(rLedgerPurch."Document No.") THEN BEGIN
                        UniqueDocNo := rPurch."Unique Document No.";
                        IF rPurch."Buy-from Vendor No." <> rLedgerPurch."Vendor No." THEN
                            IF NOT rVendor.GET(rPurch."Buy-from Vendor No.") THEN rVendor.GET(rLedgerPurch."Vendor No.");
                        if rPurch."Sub Type" = '' then rPurch."Sub Type" := gSubTypeInvDefa;
                        IF rSubTypeRef.GET(rPurch."Sub Type") THEN
                            IF rSubTypeRef.SubTypeRep = rSubTypeRef.SubTypeRep::Avoid THEN BEGIN
                                stmp2 := 'A';
                                lfactor := 0;
                            END;

                    END;


                    IF VenLedger2.GET(rLedgerPurch."Closed by Entry No.") AND (stmp2 <> 'A') THEN
                        IF VenLedger2."Document Type" IN [VenLedger2."Document Type"::"Credit Memo"] THEN BEGIN
                            IF rCreditMemoPur.GET(VenLedger2."Document No.") THEN BEGIN
                                if rCreditMemoPur."Sub Type" = '' then rCreditMemoPur."Sub Type" := gSubTypeCMDefa;
                                IF rSubTypeRef.GET(rCreditMemoPur."Sub Type") THEN
                                    IF rSubTypeRef.SubTypeRep = rSubTypeRef.SubTypeRep::Avoid THEN BEGIN
                                        stmp2 := 'A';
                                        lfactor := 0;
                                    END;
                            END;

                        END;


                    CASE rLedgerPurch."Source Code" OF
                        SourceCode.Purchases:
                            BEGIN
                                lLine1 := lLine1 + 1;
                                IF rPurch.GET(rLedgerPurch."Document No.") THEN BEGIN
                                    if rPurch."Sub Type" = '' then rPurch."Sub Type" := gSubTypeInvDefa;

                                    IF NOT rSubType.GET(rPurch."Sub Type") THEN ERROR(Text008, rPurch."No.", rPurch."Sub Type");

                                    IF pAName = pAName::Bill THEN
                                        gNameClient := rPurch."Pay-to Name" + ' ' + rPurch."Pay-to Name 2"
                                    ELSE
                                        gNameClient := rPurch."Buy-from Vendor Name" + ' ' + rPurch."Buy-from Vendor Name 2";

                                    gVAT := DELCHR(rPurch."VAT Registration No.", '=', '-');
                                    DocExttmp := rPurch."Vendor Invoice No.";
                                    AmountPoliza := rPurch."Amount FOB";
                                    //JH24072024-3 Recuperar los datos de la factura electronica con la que se registro la compra
                                    DTEAuthNumber := rPurch."DTE AuthNumber";
                                    DTEInvoice := rPurch."DTE Invoice";
                                    SignatureValidation := rPurch."Signature Validation";
                                END;
                            END;

                    END; ///case source
                END;  //Invoice


                IF rLedgerPurch."Document Type" = rLedgerPurch."Document Type"::"Credit Memo" THEN BEGIN
                    IF rCreditMemoPur.GET(rLedgerPurch."Document No.") THEN BEGIN
                        IF rCreditMemoPur."Buy-from Vendor No." <> rLedgerPurch."Vendor No."
                          THEN
                            IF NOT rVendor.GET(rCreditMemoPur."Buy-from Vendor No.") THEN rVendor.GET(rLedgerPurch."Vendor No.");
                        if rCreditMemoPur."Sub Type" = '' then rCreditMemoPur."Sub Type" := gSubTypeCMDefa;
                        IF rSubTypeRef.GET(rCreditMemoPur."Sub Type") THEN
                            IF rSubTypeRef.SubTypeRep = rSubTypeRef.SubTypeRep::Avoid THEN BEGIN
                                stmp2 := 'A';
                                lfactor := 0;
                            END;
                        UniqueDocNo := rCreditMemoPur."Unique Document No.";
                        DTEAuthNumber := rCreditMemoPur."DTE AuthNumber";
                        DTEInvoice := rCreditMemoPur."DTE Invoice";
                        SignatureValidation := rCreditMemoPur."Signature Validation";
                    END;


                    IF VenLedger2.GET(rLedgerPurch."Closed by Entry No.") AND (stmp2 <> 'A') THEN
                        IF VenLedger2."Document Type" IN [CustLedger2."Document Type"::Invoice] THEN BEGIN
                            IF rPurch.GET(rLedgerPurch."Document No.") THEN BEGIN
                                if rPurch."Sub Type" = '' then rPurch."Sub Type" := gSubTypeInvDefa;
                                IF rSubTypeRef.GET(rPurch."Sub Type") THEN
                                    IF rSubTypeRef.SubTypeRep = rSubTypeRef.SubTypeRep::Avoid THEN BEGIN
                                        stmp2 := 'A';
                                        lfactor := 0;
                                    END;
                            END;
                        END;

                    CASE rLedgerPurch."Source Code" OF
                        SourceCode.Purchases:
                            BEGIN
                                IF rCreditMemoPur.GET(rLedgerPurch."Document No.") THEN BEGIN

                                    if rCreditMemoPur."Sub Type" = '' then rCreditMemoPur."Sub Type" := gSubTypeCMDefa;

                                    IF NOT rSubType.GET(rCreditMemoPur."Sub Type") THEN ERROR(Text008, rCreditMemoPur."No.", rCreditMemoPur."Sub Type");

                                    IF pAName = pAName::Bill THEN
                                        gNameClient := rCreditMemoPur."Pay-to Name" + ' ' + rCreditMemoPur."Pay-to Name 2"
                                    ELSE
                                        gNameClient := rCreditMemoPur."Buy-from Vendor Name" + ' ' + rCreditMemoPur."Buy-from Vendor Name 2";

                                    gVAT := DELCHR(rCreditMemoPur."VAT Registration No.", '=', '-');
                                    DocExttmp := rCreditMemoPur."Vendor Cr. Memo No.";

                                END;
                            END;

                    END; //case
                END;  //Credit Memo

                ///
                IF rLedgerPurch."Payment Method Code" = 'ANUL' THEN BEGIN
                    stmp2 := 'A';
                    lfactor := 0;
                END;

                SkipEntry := FALSE;
                IF NOT rSubType."Include Ledger" THEN SkipEntry := TRUE;

                IF stmp2 = 'A' THEN SkipEntry := TRUE;

                IF NOT (SkipEntry) THEN BEGIN
                    IF gVAT = '' THEN gVAT := rVendor."VAT Registration No.";
                    IF gVAT = '' THEN gVAT := '0';
                    IF (gNameClient = '') OR (gNameClient = ' ') THEN gNameClient := rVendor.Name + ' ' + rVendor."Name 2";

                    // para lemus IF (rSubType.SubTypeRep = rSubType.SubTypeRep::Standar) OR (rSubType.SubTypeRep = rSubType.SubTypeRep::"Inv-R") THEN BEGIN
                    //    IF rCompany."Country/Region Code" <> rVendor."Country/Region Code" THEN
                    //        IF rVendor."Country/Region Code" IN ['GT', 'HN', 'SV', 'NI', 'CR', 'PA'] THEN
                    //            rSubType.SubTypeRep := rSubType.SubTypeRep::"Inv-R"
                    //        ELSE
                    //           rSubType.SubTypeRep := rSubType.SubTypeRep::"Inv-I";
                    // END;

                    stmp4 := 'S0';
                    IF DocExttmp = '' THEN DocExttmp := rLedgerPurch."External Document No.";

                    SplitDocExt(DocExttmp, stmp4, stmp5, tmpFolioYY);


                    rStamentVAT.INIT;
                    gLineNo := gLineNo + 1;
                    iLineFolio += 1;

                    IF stmp2 = 'A' THEN gNameClient := 'ANULADA';

                    rStamentVAT.Period := gPeriod;
                    rStamentVAT."Document Type" := rLedgerPurch."Document Type";
                    rStamentVAT."Entry No." := gLineNo;
                    rStamentVAT."Sub Type" := rSubType.Code;
                    rStamentVAT."Rep SubType" := rSubType.SubTypeRep;

                    rStamentVAT."Document No." := rLedgerPurch."Document No.";
                    rStamentVAT."Serie Code" := SeriePre;
                    rStamentVAT."Legal Document" := rSubType."Transaction Doc.";
                    rStamentVAT."Legal Transaction Type" := rSubType."Transaction Type";
                    rStamentVAT."Legal State" := '';
                    rStamentVAT.Type := 0;  //compras
                    rStamentVAT."Legal Serie" := stmp4;
                    rStamentVAT."Legal No." := stmp5;

                    IF iLineFolio > gPageFolio THEN BEGIN
                        iFolio += 1;
                        iLineFolio := 1;
                    END;

                    rStamentVAT.Folio := iFolio;
                    rStamentVAT."Line No." := gLineNo - (iFolio - 1) * gPageFolio;


                    rStamentVAT."Document Date" := rLedgerPurch."Document Date";
                    rStamentVAT."Posting Date" := rLedgerPurch."Posting Date";
                    //JH24072024-2 Se asigna el establecimiento según Global Dimension 1 Code. rLedgerPurch
                    rStamentVAT.Establishment := rPurch."Location Code";
                    rStamentVAT.NIT := gVAT;
                    rStamentVAT.NRC := rVendor."Federal ID No.";
                    rStamentVAT."Unique Document No." := UniqueDocNo;

                    //JH24072024-3 Recuperar los datos de la factura electronica con la que se registro la compra
                    rStamentVAT."DTE AuthNumber" := DTEAuthNumber;
                    rStamentVAT."DTE Invoice" := DTEInvoice;
                    rStamentVAT."Signature Validation" := SignatureValidation;

                    rStamentVAT.Name := gNameClient;
                    IF rSubType.SubTypeRep = rSubType.SubTypeRep::"Inv-Spec" THEN BEGIN
                        GetIdentif(rVendor."CURP No.");
                        rStamentVAT."Identif No." := Identif2;
                        rStamentVAT."Identif Order" := Identif1;
                    END;
                    // ELSE  rStamentVAT.NCR:=rVendor."CURP No.";

                    VATEntry.SETCURRENTKEY("Document No.", "Posting Date");
                    VATEntry.SETRANGE("Document No.", rLedgerPurch."Document No.");
                    VATEntry.SETRANGE(Type, VATEntry.Type::Purchase);
                    VATEntry.SETRANGE("Source Code", rLedgerPurch."Source Code");
                    VATEntry.SETRANGE("Posting Date", rLedgerPurch."Posting Date");

                    CLEAR(ATOTAL);
                    GetValueVAT(VATEntry, ATOTAL, lfactor, sdoc);

                    if ComputeWithholdingTax.Get(rLedgerPurch."Vendor No.", rLedgerPurch."Document Date",
                      rLedgerPurch."Document No.") then begin
                        //if rSubType.SubTypeRep =rSubType.SubTypeRep::"Small Contributo" then
                        ATOTAL[16] += ComputeWithholdingTax."Withholding Tax Amount ISR";
                        ATOTAL[17] += ComputeWithholdingTax."Withholding Tax Amount Others" +
                        ComputeWithholdingTax."Withholding Tax Amount VAT" +
                        ComputeWithholdingTax."Withholding Tax Amount VAT 2";
                    end;


                    CASE rSubType.SubTypeRep OF
                        rSubType.SubTypeRep::Standar:
                            BEGIN
                                rStamentVAT."Base Affect Goods" := ATOTAL[1];
                                rStamentVAT."Base Affect Service" := ATOTAL[2];
                                rStamentVAT."Excent Goods" := ATOTAL[3];
                                rStamentVAT."Excent Service" := ATOTAL[4];
                                rStamentVAT."VAT Affect Goods" := ATOTAL[31];
                                rStamentVAT."VAT Affect Service" := ATOTAL[32];
                                stmp1 := 'L';
                            END;

                        rSubType.SubTypeRep::"Inv-R":
                            BEGIN

                                IF AmountPoliza > 0 THEN BEGIN
                                    ;
                                    ATOTAL[1] := AmountPoliza;
                                    ATOTAL[2] := 0;
                                    ATOTAL[3] := 0;
                                    ATOTAL[4] := 0;
                                    ATOTAL[21] := ATOTAL[1] + ATOTAL[20];
                                    ATOTAL[22] := ATOTAL[1];
                                END;

                                IF (LastRateVAT <> 0) AND

                                (ATOTAL[1] = 0) AND (ATOTAL[2] = 0) AND (ATOTAL[3] = 0) AND (ATOTAL[4] = 0) AND (ATOTAL[20] > 0) THEN BEGIN
                                    ATOTAL[1] := ROUND(ATOTAL[20] * 100 / LastRateVAT, 0.01);
                                    ATOTAL[21] := ATOTAL[1] + ATOTAL[20];
                                    ATOTAL[22] := ATOTAL[1];
                                END;

                                rStamentVAT."Base Internac Goods" := ATOTAL[1];
                                rStamentVAT."Base Internac Service" := ATOTAL[2];
                                rStamentVAT."Excent Internac Goods" := ATOTAL[3];
                                rStamentVAT."Excent Internac Service" := ATOTAL[4];
                                rStamentVAT."VAT Internac Goods" := ATOTAL[20];
                                rStamentVAT."VAT Internac Goods" := ATOTAL[31];
                                rStamentVAT."VAT Internac Service" := ATOTAL[32];
                                stmp1 := 'R';
                            END;

                        rSubType.SubTypeRep::"Inv-I":
                            BEGIN

                                IF AmountPoliza > 0 THEN BEGIN
                                    ;
                                    ATOTAL[1] := AmountPoliza;
                                    ATOTAL[2] := 0;
                                    ATOTAL[3] := 0;
                                    ATOTAL[4] := 0;
                                    ATOTAL[21] := ATOTAL[1] + ATOTAL[20];
                                    ATOTAL[22] := ATOTAL[1];
                                END;

                                IF (LastRateVAT <> 0) AND

                                   (ATOTAL[1] = 0) AND (ATOTAL[2] = 0) AND (ATOTAL[3] = 0) AND (ATOTAL[4] = 0) AND (ATOTAL[20] > 0) THEN BEGIN
                                    ATOTAL[1] := ROUND(ATOTAL[20] * 100 / LastRateVAT, 0.01);
                                    ATOTAL[21] := ATOTAL[1] + ATOTAL[20];
                                    ATOTAL[22] := ATOTAL[1];
                                END;

                                rStamentVAT."Base Inter Goods" := ATOTAL[1];
                                rStamentVAT."Base Inter Service" := ATOTAL[2];
                                rStamentVAT."Excent Inter Goods" := ATOTAL[3];
                                rStamentVAT."Excent Inter Service" := ATOTAL[4];
                                rStamentVAT."VAT Inter Goods" := ATOTAL[20];
                                rStamentVAT."VAT Inter Goods" := ATOTAL[31];
                                rStamentVAT."VAT Inter Service" := ATOTAL[32];
                                stmp1 := 'E';
                            END;

                        rSubType.SubTypeRep::"Small Contributo":
                            BEGIN
                                rStamentVAT."Small Contributor Goods" := ATOTAL[1] + ATOTAL[31] + ATOTAL[3] + ATOTAL[33];
                                rStamentVAT."Small Contributor Service" := ATOTAL[2] + ATOTAL[32] + ATOTAL[4] + ATOTAL[34];
                                ATOTAL[22] := ATOTAL[21];
                            END;

                        rSubType.SubTypeRep::"Inv-Spec":
                            BEGIN
                                rStamentVAT."Base Special Invoice Goods" := ATOTAL[1] + ATOTAL[3];
                                rStamentVAT."Base Special Invoice  Service" := ATOTAL[2] + ATOTAL[4];
                                rStamentVAT."VAT Special Goods" := ATOTAL[31];
                                rStamentVAT."VAT Special Service" := ATOTAL[32];
                                //ATOTAL[22]:=ATOTAL[21];
                            END;


                    END;


                    IF IsCompany3rd THEN BEGIN
                        rStamentVAT."Base 3rd Goods" := ATOTAL[1];
                        rStamentVAT."Base 3rd Service" := ATOTAL[2];
                        rStamentVAT."Excent 3rd Goods" := ATOTAL[3];
                        rStamentVAT."Excent 3rd Service" := ATOTAL[4];
                        rStamentVAT."VAT 3rd" := ATOTAL[20];
                        rStamentVAT."Ret VAT 3rd" := ATOTAL[17];
                        IF rSubType.SubTypeRep = rSubType.SubTypeRep::"Inv-Spec" THEN BEGIN
                            rStamentVAT."Base 3rd Goods" := ATOTAL[1] + ATOTAL[31];
                            rStamentVAT."Base 3rd Service" := ATOTAL[2] + ATOTAL[32];
                            rStamentVAT."Excent 3rd Goods" := ATOTAL[3] + ATOTAL[33];
                            rStamentVAT."Excent 3rd Service" := ATOTAL[4] + ATOTAL[34];
                            rStamentVAT."VAT 3rd" := ATOTAL[20];
                            rStamentVAT."Ret VAT 3rd" := ATOTAL[17];
                            ATOTAL[22] := ATOTAL[21];  //subtotal = total
                        END;
                        ATOTAL[1] := 0;
                        ATOTAL[2] := 0;
                        ATOTAL[3] := 0;
                        ATOTAL[4] := 0
                    END;


                    IF stmp2 = 'A' THEN CLEAR(ATOTAL);

                    //rStamentVAT."Legal Transaction Type":=stmp1;
                    rStamentVAT."Gas 1" := ATOTAL[11];
                    rStamentVAT."Gas 2" := ATOTAL[12];
                    rStamentVAT.Tourist := ATOTAL[13];
                    rStamentVAT.Alcohol := ATOTAL[14];

                    rStamentVAT."Ret Inc" := ATOTAL[16];
                    rStamentVAT."Ret VAT" := ATOTAL[17];
                    rStamentVAT."Ret NS" := ATOTAL[18];
                    rStamentVAT.Exencion := ATOTAL[19];

                    rStamentVAT."Sub Total" := ATOTAL[22];
                    rStamentVAT.VAT := ATOTAL[20];
                    rStamentVAT.Total := ATOTAL[21];
                    IF rSubTypeRef.Code = '' THEN
                        rStamentVAT."Prices Including VAT" := rSubType."Prices Including VAT"
                    ELSE
                        rStamentVAT."Prices Including VAT" := rSubTypeRef."Prices Including VAT";

                    rStamentVAT."Shortcut Dimension 1 Code" := rLedgerPurch."Global Dimension 1 Code";
                    rStamentVAT."Shortcut Dimension 2 Code" := rLedgerPurch."Global Dimension 2 Code";
                    rStamentVAT."Region Country" := rVendor."Country/Region Code";
                    rStamentVAT.Dispositive := gDispositive;
                    rStamentVAT."Source Code" := rLedgerPurch."Source Code";

                    IF pAName = pAName::Bill THEN
                        rStamentVAT."Customer No." := rLedgerPurch."Vendor No."
                    ELSE
                        rStamentVAT."Customer No." := rVendor."No.";


                    IF rLedgerPurch."Document Type" = rLedgerPurch."Document Type"::Invoice THEN
                        DocLegal.SETRANGE("Document Type", DocLegal."Document Type"::"Purchase Invoice");

                    IF rLedgerPurch."Document Type" = rLedgerPurch."Document Type"::"Credit Memo" THEN
                        DocLegal.SETRANGE("Document Type", DocLegal."Document Type"::"POS Credit Memo");

                    DocLegal.SETRANGE("No.", rLedgerPurch."Document No.");
                    DocLegal.SETFILTER("Line No.", '<>0');
                    tmpLd := '';

                    IF DocLegal.FINDFIRST THEN
                        REPEAT
                            IF tmpLd = '' THEN
                                tmpLd := DocLegal.Number
                            ELSE
                                tmpLd += ', ' + DocLegal.Number;
                        UNTIL DocLegal.NEXT = 0;

                    //rStamentVAT."Constancy Type":='ss';
                    rStamentVAT."Constancy No." := COPYSTR(tmpLd, 1, 30);

                    IF CloseVATentry = 0 THEN
                        rStamentVAT.INSERT
                    ELSE BEGIN
                        rStatementLegal.SETRANGE(Type, CurrentType);
                        rStatementLegal.SETRANGE(Period, gPeriod);
                        rStatementLegal.SETRANGE("Closed by Entry No.", CloseVATentry);
                        rStamentVAT."Closed by Entry No." := CloseVATentry;
                        IF NOT rStatementLegal.FINDFIRST THEN
                            rStamentVAT.INSERT
                        ELSE
                            gLineNo -= 1;
                    END;


                END;  //SKIPENTRY




            UNTIL rLedgerPurch.NEXT = 0;

        //retenciones     
        computeWht.RESET;
        computeWht.SETRANGE("Posting Date", FiltDate1, FiltDate2);
        IF DocNo <> '' THEN
            computeWht.SETFILTER("Document No.", DocNo);


        wd.UPDATE(3, computeWht.COUNT);
        if computeWht.FindFirst() then
            repeat
                stmp2 := '';
                SkipEntry := false;
                if WithholdCode.Get(ComputeWht."Withholding Tax Code") then
                    SkipEntry := not WithholdCode."Include Ledger";

                if not SkipEntry then
                    SkipEntry := computeWht."Close Apply No." < 0;

                if NOT SkipEntry then begin

                    rLedgerPurch.SetRange("Posting Date", computeWht."Posting Date");
                    rLedgerPurch.SetRange("Document No.", computeWht."Document No.");
                    if not rLedgerPurch.FindFirst() then rLedgerPurch.Init();

                    VATledgerREf.SetRange("Document No.", rLedgerPurch."Document No.");
                    VATledgerREf.SetRange(Period, gPeriod);
                    VATledgerREf.SetRange(TYPE, 0);

                    IF NOT VATledgerREf.FindFirst() then VATledgerREf.INIT;

                    rVendor.Get(ComputeWht."Vendor No.");
                    iLineFolio += 1;
                    gNameClient := rLedgerPurch."Vendor Name";
                    IF stmp2 = 'A' THEN gNameClient := 'ANULADA';
                    rStamentVAT.INIT;
                    rStamentVAT.NIT := VATledgerREf.NIT;
                    rStamentVAT.NRC := VATledgerREf.NRC;
                    rStamentVAT.Name := VATledgerREf.Name;
                    rStamentVAT."Document Date" := VATledgerREf."Document Date";
                    rStamentVAT."Identif No." := VATledgerREf."Identif No.";
                    rStamentVAT."Identif Order" := VATledgerREf."Identif Order";
                    rStamentVAT.Period := gPeriod;
                    rStamentVAT."Document Type" := rStamentVAT."Document Type"::"Withholding Tax";
                    rStamentVAT."Entry No." := gLineNo;
                    // rStamentVAT."Sub Type" := rSubType.Code;
                    // rStamentVAT."Rep SubType" := rSubType.SubTypeRep;

                    rStamentVAT."Document No." := computeWht."Document No.";
                    // rStamentVAT."Serie Code" := SeriePre;
                    // rStamentVAT."Legal Document" := rSubType."Transaction Doc.";
                    // rStamentVAT."Legal Transaction Type" := rSubType."Transaction Type";
                    //  rStamentVAT."Legal State" := stmp2;

                    // IF SerieEstable = '' THEN SerieEstable := rSubType.Establishment;
                    //  rStamentVAT.Establishment := SerieEstable;


                    rStamentVAT.Type := 0;  //compras
                                            //rStamentVAT."Legal Document":=sdoc;
                                            //rStamentVAT."Legal Serie" := stmp4;
                    rStamentVAT."Legal No." := computeWht."Withhold ISR No.";

                    IF iLineFolio > gPageFolio THEN BEGIN
                        iFolio += 1;
                        iLineFolio := 1;
                    END;

                    rStamentVAT.Folio := iFolio;
                    rStamentVAT."Line No." := gLineNo - (iFolio - 1) * gPageFolio;

                    rStamentVAT."Document Date" := computeWht."Document Date";
                    rStamentVAT."Posting Date" := computeWht."Posting Date";
                    rStamentVAT.NIT := rVendor."VAT Registration No.";
                    rStamentVAT.NRC := rVendor."State Inscription";
                    rStamentVAT.Name := gNameClient;
                    // rStamentVAT."Custom Region" := lRegion;
                    // rStamentVAT."Customs Form" := CustomForm;
                    rStamentVAT."Customer No." := rLedgerPurch."Vendor No.";
                    CLEAR(ATOTAL);
                    //   rStamentVAT."Prices Including VAT" := rSubType."Prices Including VAT";
                    rStamentVAT."Shortcut Dimension 1 Code" := rLedgerPurch."Global Dimension 1 Code";
                    rStamentVAT."Shortcut Dimension 2 Code" := rLedgerPurch."Global Dimension 2 Code";

                    //LegalLedger.SetRange("Document Type", rLedgerPurch."Document Type");
                    LegalLedger.SetRange("No.", rLedgerPurch."Document No.");

                    if ComputeWht."Withholding Tax Amount ISR" > 0 then begin
                        rStamentVAT."Withholding No." := '';
                        ATOTAL[16] := -ComputeWht."Withholding Tax Amount ISR";
                        ATOTAL[17] := 0;
                        ComputeWht.CalcFields("Withhold ISR No.", "Withhold Tax No.");

                        LegalDoc.SetRange(Type, LegalDoc.Type::ISR);
                        IF LegalDoc.FindFirst() Then begin

                            LegalLedger.SetRange("Legal Doc Code", LegalDoc.Code);
                            if LegalLedger.FindFirst() then begin
                                rStamentVAT."Withholding No." := LegalLedger.Number;
                                //DTE_V1.25JH*******************
                                rStamentVAT."DTE AuthNumber" := LegalLedger."DTE AuthNumber";
                                rStamentVAT."DTE Invoice" := LegalLedger."DTE Invoice";
                                rStamentVAT."Signature Validation" := LegalLedger."Signature Validation";
                                //DTE_V1.25JH*******************
                            end;

                        end;


                        gLineNo := gLineNo + 1;

                        if rStamentVAT."Withholding No." = '' then
                            rStamentVAT."Withholding No." := ComputeWht."Withhold ISR No.";
                        rStamentVAT."Entry No." := gLineNo;
                        rStamentVAT."Ret Inc" := ATOTAL[16];
                        rStamentVAT."Ret VAT" := ATOTAL[17];
                        rStamentVAT."Ret NS" := ATOTAL[18];
                        rStamentVAT."Sub Total" := ATOTAL[22];
                        rStamentVAT."Withholding Base" := ComputeWht."Taxable Base ISR";
                        rStamentVAT.VAT := ATOTAL[20];
                        rStamentVAT.Total := ATOTAL[21];
                        rStamentVAT.Insert();
                    end;

                    if ComputeWht."Withholding Tax Amount VAT" > 0 then begin
                        ATOTAL[17] := -ComputeWht."Withholding Tax Amount VAT";
                        ATOTAL[16] := 0;
                        rStamentVAT."Withholding No." := '';

                        LegalDoc.SetRange(Type, LegalDoc.Type::VAT);
                        IF LegalDoc.FindFirst() Then begin
                            LegalLedger.SetRange("Legal Doc Code", LegalDoc.Code);
                            if LegalLedger.FindFirst() then begin
                                rStamentVAT."Withholding No." := LegalLedger.Number;
                                //DTE_V1.25JH*******************
                                rStamentVAT."DTE AuthNumber" := LegalLedger."DTE AuthNumber";
                                rStamentVAT."DTE Invoice" := LegalLedger."DTE Invoice";
                                rStamentVAT."Signature Validation" := LegalLedger."Signature Validation";
                                //DTE_V1.25JH*******************
                            end;
                        end;
                        gLineNo := gLineNo + 1;
                        if rStamentVAT."Withholding No." = '' then
                            rStamentVAT."Withholding No." := ComputeWht."Withhold Tax No.";
                        rStamentVAT."Entry No." := gLineNo;
                        rStamentVAT."Ret Inc" := ATOTAL[16];
                        rStamentVAT."Ret VAT" := ATOTAL[17];
                        rStamentVAT."Ret NS" := ATOTAL[18];
                        rStamentVAT."Sub Total" := ATOTAL[22];
                        rStamentVAT.VAT := ATOTAL[20];
                        rStamentVAT.Total := ATOTAL[21];
                        rStamentVAT."Withholding Base" := ComputeWht."Taxable Base VAT";
                        rStamentVAT.Insert();
                    end;

                    if ComputeWht."Withholding Tax Amount Others" > 0 then begin
                        ATOTAL[17] := -ComputeWht."Withholding Tax Amount Others";
                        ATOTAL[16] := 0;
                        rStamentVAT."Withholding No." := '';
                        LegalDoc.SetRange(Type, LegalDoc.Type::OTHER);
                        IF LegalDoc.FindFirst() Then begin
                            LegalLedger.SetRange("Legal Doc Code", LegalDoc.Code);
                            if LegalLedger.FindFirst() then begin
                                rStamentVAT."Withholding No." := LegalLedger.Number;
                                //DTE_V1.25JH*******************
                                rStamentVAT."DTE AuthNumber" := LegalLedger."DTE AuthNumber";
                                rStamentVAT."DTE Invoice" := LegalLedger."DTE Invoice";
                                rStamentVAT."Signature Validation" := LegalLedger."Signature Validation";
                                //DTE_V1.25JH*******************
                            end;
                        end;
                        gLineNo := gLineNo + 1;
                        if rStamentVAT."Withholding No." = '' then
                            rStamentVAT."Withholding No." := ComputeWht."Withhold Tax No.";
                        rStamentVAT."Entry No." := gLineNo;
                        rStamentVAT."Ret Inc" := ATOTAL[16];
                        rStamentVAT."Ret VAT" := ATOTAL[17];
                        rStamentVAT."Ret NS" := ATOTAL[18];
                        rStamentVAT."Sub Total" := ATOTAL[22];
                        rStamentVAT.VAT := ATOTAL[20];
                        rStamentVAT.Total := ATOTAL[21];
                        rStamentVAT."Withholding Base" := ComputeWht."Taxable Base Other";
                        rStamentVAT.Insert();
                    end;

                    if ComputeWht."Withholding Tax Amount VAT 2" > 0 then begin
                        ATOTAL[17] := -ComputeWht."Withholding Tax Amount VAT 2";
                        ATOTAL[16] := 0;
                        rStamentVAT."Withholding No." := '';
                        LegalDoc.SetRange(Type, LegalDoc.Type::"VAT 2");
                        IF LegalDoc.FindFirst() Then begin
                            LegalLedger.SetRange("Legal Doc Code", LegalDoc.Code);
                            if LegalLedger.FindFirst() then
                                rStamentVAT."Withholding No." := LegalLedger.Number;
                        end;

                        gLineNo := gLineNo + 1;
                        if rStamentVAT."Withholding No." = '' then
                            rStamentVAT."Withholding No." := ComputeWht."Withhold Tax No.";
                        rStamentVAT."Entry No." := gLineNo;
                        rStamentVAT."Ret Inc" := ATOTAL[16];
                        rStamentVAT."Ret VAT" := ATOTAL[17];
                        rStamentVAT."Ret NS" := ATOTAL[18];
                        rStamentVAT."Sub Total" := ATOTAL[22];
                        rStamentVAT.VAT := ATOTAL[20];
                        rStamentVAT.Total := ATOTAL[21];
                        rStamentVAT."Withholding Base" := ComputeWht."Taxable Base VAT 2";
                        rStamentVAT.Insert();
                    end;
                end;

            until computeWht.Next() = 0;
    end;

    local procedure GetIdentif(pDoc: Text[20]);
    var
        parti: Integer;
        partj: Integer;
    begin
        parti := STRPOS(pDoc, '-');
        IF parti > 0 THEN BEGIN
            Identif1 := COPYSTR(pDoc, 1, parti - 1);
            Identif2 := COPYSTR(pDoc, parti + 1);
            EXIT;
        END;

        parti := STRPOS(pDoc, ' ');
        IF parti > 0 THEN BEGIN
            Identif1 := COPYSTR(pDoc, 1, parti - 1);
            Identif2 := COPYSTR(pDoc, parti + 1);
            EXIT;
        END;

        FOR partj := 1 TO STRLEN(pDoc) DO
            IF COPYSTR(pDoc, partj, 1) IN ['0', '1', '3', '4', '5', '6', '7', '8', '9'] THEN BEGIN
                parti := partj;
                partj := STRLEN(pDoc) + 1;
            END;

        IF parti > 1 THEN BEGIN
            Identif1 := COPYSTR(pDoc, 1, parti - 1);
            Identif2 := COPYSTR(pDoc, parti + 1);
            EXIT;
        END;

        Identif1 := '';
        Identif2 := pDoc;
    end;

    procedure ExplodeDocNo(DocNo: Code[20]; VAR StoreNo: Code[10]; VAR PosNo: Code[10]; VAR TransNo: Integer)
    var
        Position: Integer;
    begin
        StoreNo := '';
        PosNo := '';
        TransNo := 0;

        Position := STRPOS(DocNo, '-');
        if Position < 2 then exit;
        StoreNo := CopyStr(DocNo, 1, Position - 1);
        DocNo := COPYSTR(DocNo, Position + 1);

        Position := STRPOS(DocNo, '-');
        if Position < 2 then exit;
        PosNo := CopyStr(DocNo, 1, Position - 1);

        DocNo := COPYSTR(DocNo, Position + 1);

        if not EVALUATE(TransNo, DocNo) then TransNo := 0;
        exit;
    end;

}

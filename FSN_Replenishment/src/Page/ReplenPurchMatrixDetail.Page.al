page 50045 "FSN Replen. By Location Matrix"
{
    Caption = 'Items by Location Matrix';
    Editable = true;
    LinksAllowed = false;
    PageType = List;
    SourceTable = "FSN Replen. Template Matrix";

    layout
    {
        area(content)
        {
            repeater("Matrix")
            {
                FreezeColumn = "Direct Unit Cost";
                field("Barcode No."; "Barcode No.")
                {
                    Caption = 'Barcode';
                    Editable = false;
                    StyleExpr = Style;
                }
                field(Description; Description)
                {
                    Caption = 'Description';
                    Editable = false;
                    StyleExpr = Style;
                }
                field("Purc. Unit of Measure"; "Purc. Unit of Measure")
                {
                    Editable = false;
                    StyleExpr = Style;
                }
                field("Attrib 1 Code"; "Attrib 1 Code")
                {
                    Caption = 'Attribute 1';
                    Editable = false;
                    StyleExpr = Style;
                }
                field("Direct Unit Cost"; "Direct Unit Cost")
                {
                    Caption = 'Direct. Cost';
                    Editable = false;
                    StyleExpr = Style;
                }

                //group()
                //{
                field(Field1; MATRIX_CellData[1])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[1];
                    DecimalPlaces = 0 : 5;
                    Style = Favorable;
                    StyleExpr = TRUE;
                    Visible = Field1Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(1);
                    end;
                }
                field(Field2; MATRIX_CellData[2])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[2];
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    QuickEntry = false;
                    Style = Ambiguous;
                    StyleExpr = TRUE;
                    Visible = Field2Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(2);
                    end;
                }
                field(Field3; MATRIX_CellData[3])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[3];
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    QuickEntry = false;
                    Style = Subordinate;
                    StyleExpr = TRUE;
                    Visible = Field3Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(3);
                    end;
                }
                field(Field4; MATRIX_CellData[4])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[4];
                    DecimalPlaces = 0 : 5;
                    Style = StandardAccent;
                    StyleExpr = TRUE;
                    Visible = Field4Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(4);
                    end;
                }
                field(Field5; MATRIX_CellData[5])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[5];
                    DecimalPlaces = 0 : 5;
                    Style = Favorable;
                    StyleExpr = TRUE;
                    Visible = Field5Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(5);
                    end;
                }
                field(Field6; MATRIX_CellData[6])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[6];
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    QuickEntry = false;
                    Style = Ambiguous;
                    StyleExpr = TRUE;
                    Visible = Field6Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(6);
                    end;
                }
                field(Field7; MATRIX_CellData[7])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[7];
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    QuickEntry = false;
                    Style = Subordinate;
                    StyleExpr = TRUE;
                    Visible = Field7Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(7);
                    end;
                }
                field(Field8; MATRIX_CellData[8])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[8];
                    DecimalPlaces = 0 : 5;
                    Style = StandardAccent;
                    StyleExpr = TRUE;
                    Visible = Field8Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(8);
                    end;
                }
                field(Field9; MATRIX_CellData[9])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[9];
                    DecimalPlaces = 0 : 5;
                    Style = Favorable;
                    StyleExpr = TRUE;
                    Visible = Field9Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(9);
                    end;
                }
                field(Field10; MATRIX_CellData[10])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[10];
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    QuickEntry = false;
                    Style = Ambiguous;
                    StyleExpr = TRUE;
                    Visible = Field10Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(10);
                    end;
                }
                field(Field11; MATRIX_CellData[11])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[11];
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    QuickEntry = false;
                    Style = Subordinate;
                    StyleExpr = TRUE;
                    Visible = Field11Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(11);
                    end;
                }
                field(Field12; MATRIX_CellData[12])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[12];
                    DecimalPlaces = 0 : 5;
                    Style = StandardAccent;
                    StyleExpr = TRUE;
                    Visible = Field12Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(12);
                    end;
                }
                field(Field13; MATRIX_CellData[13])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[13];
                    DecimalPlaces = 0 : 5;
                    Style = Favorable;
                    StyleExpr = TRUE;
                    Visible = Field13Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(13);
                    end;
                }
                field(Field14; MATRIX_CellData[14])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[14];
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    QuickEntry = false;
                    Style = Ambiguous;
                    StyleExpr = TRUE;
                    Visible = Field14Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(14);
                    end;
                }
                field(Field15; MATRIX_CellData[15])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[15];
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    QuickEntry = false;
                    Style = Subordinate;
                    StyleExpr = TRUE;
                    Visible = Field15Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(15);
                    end;
                }
                field(Field16; MATRIX_CellData[16])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[16];
                    DecimalPlaces = 0 : 5;
                    Style = StandardAccent;
                    StyleExpr = TRUE;
                    Visible = Field16Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(16);
                    end;
                }
                field(Field17; MATRIX_CellData[17])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[17];
                    DecimalPlaces = 0 : 5;
                    Style = Favorable;
                    StyleExpr = TRUE;
                    Visible = Field17Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(17);
                    end;
                }
                field(Field18; MATRIX_CellData[18])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[18];
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    QuickEntry = false;
                    Style = Ambiguous;
                    StyleExpr = TRUE;
                    Visible = Field18Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(18);
                    end;
                }
                field(Field19; MATRIX_CellData[19])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[19];
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    QuickEntry = false;
                    Style = Subordinate;
                    StyleExpr = TRUE;
                    Visible = Field19Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(19);
                    end;
                }
                field(Field20; MATRIX_CellData[20])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[20];
                    DecimalPlaces = 0 : 5;
                    Style = StandardAccent;
                    StyleExpr = TRUE;
                    Visible = Field20Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(20);
                    end;
                }
                field(Field21; MATRIX_CellData[21])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[21];
                    DecimalPlaces = 0 : 5;
                    Style = Favorable;
                    StyleExpr = TRUE;
                    Visible = Field21Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(21);
                    end;
                }
                field(Field22; MATRIX_CellData[22])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[22];
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    QuickEntry = false;
                    Style = Ambiguous;
                    StyleExpr = TRUE;
                    Visible = Field22Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(22);
                    end;
                }
                field(Field23; MATRIX_CellData[23])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[23];
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    QuickEntry = false;
                    Style = Subordinate;
                    StyleExpr = TRUE;
                    Visible = Field23Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(23);
                    end;
                }
                field(Field24; MATRIX_CellData[24])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[24];
                    DecimalPlaces = 0 : 5;
                    Style = StandardAccent;
                    StyleExpr = TRUE;
                    Visible = Field24Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(24);
                    end;
                }
                field(Field25; MATRIX_CellData[25])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[25];
                    DecimalPlaces = 0 : 5;
                    Style = Favorable;
                    StyleExpr = TRUE;
                    Visible = Field25Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(25);
                    end;
                }
                field(Field26; MATRIX_CellData[26])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[26];
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    QuickEntry = false;
                    Style = Ambiguous;
                    StyleExpr = TRUE;
                    Visible = Field26Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(26);
                    end;
                }
                field(Field27; MATRIX_CellData[27])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[27];
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    QuickEntry = false;
                    Style = Subordinate;
                    StyleExpr = TRUE;
                    Visible = Field27Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(27);
                    end;
                }
                field(Field28; MATRIX_CellData[28])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[28];
                    DecimalPlaces = 0 : 5;
                    Style = StandardAccent;
                    StyleExpr = TRUE;
                    Visible = Field28Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(28);
                    end;
                }
                field(Field29; MATRIX_CellData[29])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[29];
                    DecimalPlaces = 0 : 5;
                    Style = Favorable;
                    StyleExpr = TRUE;
                    Visible = Field29Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(29);
                    end;
                }
                field(Field30; MATRIX_CellData[30])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[30];
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    QuickEntry = false;
                    Style = Ambiguous;
                    StyleExpr = TRUE;
                    Visible = Field30Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(30);
                    end;
                }
                field(Field31; MATRIX_CellData[31])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[31];
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                    QuickEntry = false;
                    Style = Subordinate;
                    StyleExpr = TRUE;
                    Visible = Field31Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(31);
                    end;
                }
                field(Field32; MATRIX_CellData[32])
                {
                    BlankNumbers = DontBlank;
                    CaptionClass = '3,' + MATRIX_ColumnCaption[32];
                    DecimalPlaces = 0 : 5;
                    Style = StandardAccent;
                    StyleExpr = TRUE;
                    Visible = Field32Visible;
                    Width = 5;

                    trigger OnValidate()
                    begin
                        OnValidateTmp(32);
                    end;
                }
                //}
            }
        }
    }

    actions
    {
        area(navigation)
        {
            group("&Item")
            {
                Caption = '&Item';
                Image = Item;
                group("&Item Availability by")
                {
                    Caption = '&Item Availability by';
                    Image = ItemAvailability;
                    action(Period)
                    {
                        Caption = 'Period';
                        Image = Period;
                        RunObject = Page 157;
                    }
                    action(Variant)
                    {
                        Caption = 'Variant';
                        Image = ItemVariant;
                        RunObject = Page 5414;
                    }
                    action(Location)
                    {
                        Caption = 'Location';
                        Image = Warehouse;
                        RunObject = Page 492;
                    }
                    /*
                    action("BOM Level")
                    {
                        Caption = 'BOM Level';
                        Image = BOMLevel;

                        trigger OnAction()
                        begin
                            //ItemAvailFormsMgt.ShowItemAvailFromItem(Rec,ItemAvailFormsMgt.ByEvent);
                        end;
                    }
                    */
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        MATRIX_CurrentColumnOrdinal: Integer;
    begin
        MATRIX_CurrentColumnOrdinal := 0;
        IF MatrixRecord.FIND('-') THEN
            REPEAT
                MATRIX_CurrentColumnOrdinal := MATRIX_CurrentColumnOrdinal + 1;
                MATRIX_OnAfterGetRecordQty(MATRIX_CurrentColumnOrdinal);
                MATRIX_CurrentColumnOrdinal := MATRIX_CurrentColumnOrdinal + 1;
                MATRIX_OnAfterGetRecordAvg(MATRIX_CurrentColumnOrdinal);
                MATRIX_CurrentColumnOrdinal := MATRIX_CurrentColumnOrdinal + 1;
                MATRIX_OnAfterGetRecordInv(MATRIX_CurrentColumnOrdinal);
                MATRIX_CurrentColumnOrdinal := MATRIX_CurrentColumnOrdinal + 1;
                MATRIX_OnAfterGetRecordBon(MATRIX_CurrentColumnOrdinal);
            UNTIL (MatrixRecord.NEXT(1) = 0) OR (MATRIX_CurrentColumnOrdinal = MATRIX_NoOfMatrixColumns);

        CurrPage.UPDATE(FALSE);
    end;

    trigger OnInit()
    var
        i: Integer;
    begin
        Field32Visible := TRUE;
        Field31Visible := TRUE;
        Field30Visible := TRUE;
        Field29Visible := TRUE;
        Field28Visible := TRUE;
        Field27Visible := TRUE;
        Field26Visible := TRUE;
        Field25Visible := TRUE;
        Field24Visible := TRUE;
        Field23Visible := TRUE;
        Field22Visible := TRUE;
        Field21Visible := TRUE;
        Field20Visible := TRUE;
        Field19Visible := TRUE;
        Field18Visible := TRUE;
        Field17Visible := TRUE;
        Field16Visible := TRUE;
        Field15Visible := TRUE;
        Field14Visible := TRUE;
        Field13Visible := TRUE;
        Field12Visible := TRUE;
        Field11Visible := TRUE;
        Field10Visible := TRUE;
        Field9Visible := TRUE;
        Field8Visible := TRUE;
        Field7Visible := TRUE;
        Field6Visible := TRUE;
        Field5Visible := TRUE;
        Field4Visible := TRUE;
        Field3Visible := TRUE;
        Field2Visible := TRUE;
        Field1Visible := TRUE;

        ColWidth := 5;
    end;

    trigger OnOpenPage()
    var
        i: Integer;
    begin
        MATRIX_NoOfMatrixColumns := ARRAYLEN(MATRIX_CellData);
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        i: Integer;
        lTxt1: Label 'Have %1 item rewards for item %2';
    begin
        //CSMQ130216 Validacion para evitar cerrar
        FOR i := 1 TO TempCustItems.COUNT DO
            IF (bonusdifference[i] > 0) AND TempCustItems.GET("Replenishment Template Code", (i * 10000)) THEN
                ERROR(lTxt1, bonusdifference[i], TempCustItems."Barcode No.");
    end;

    var
        JournalDetails: Record "LSC Replen. Jrnl. Details";
        MatrixRecords: array[32] of Record "Location";
        MatrixRecord: Record "Location";
        MATRIX_NoOfMatrixColumns: Integer;
        MATRIX_CellData: array[32] of Decimal;
        MATRIX_ColumnCaption: array[32] of Text[1024];
        [InDataSet]
        Field1Visible: Boolean;
        [InDataSet]
        Field2Visible: Boolean;
        [InDataSet]
        Field3Visible: Boolean;
        [InDataSet]
        Field4Visible: Boolean;
        [InDataSet]
        Field5Visible: Boolean;
        [InDataSet]
        Field6Visible: Boolean;
        [InDataSet]
        Field7Visible: Boolean;
        [InDataSet]
        Field8Visible: Boolean;
        [InDataSet]
        Field9Visible: Boolean;
        [InDataSet]
        Field10Visible: Boolean;
        [InDataSet]
        Field11Visible: Boolean;
        [InDataSet]
        Field12Visible: Boolean;
        [InDataSet]
        Field13Visible: Boolean;
        [InDataSet]
        Field14Visible: Boolean;
        [InDataSet]
        Field15Visible: Boolean;
        [InDataSet]
        Field16Visible: Boolean;
        [InDataSet]
        Field17Visible: Boolean;
        [InDataSet]
        Field18Visible: Boolean;
        [InDataSet]
        Field19Visible: Boolean;
        [InDataSet]
        Field20Visible: Boolean;
        [InDataSet]
        Field21Visible: Boolean;
        [InDataSet]
        Field22Visible: Boolean;
        [InDataSet]
        Field23Visible: Boolean;
        [InDataSet]
        Field24Visible: Boolean;
        [InDataSet]
        Field25Visible: Boolean;
        [InDataSet]
        Field26Visible: Boolean;
        [InDataSet]
        Field27Visible: Boolean;
        [InDataSet]
        Field28Visible: Boolean;
        [InDataSet]
        Field29Visible: Boolean;
        [InDataSet]
        Field30Visible: Boolean;
        [InDataSet]
        Field31Visible: Boolean;
        [InDataSet]
        Field32Visible: Boolean;
        ColWidth: Integer;
        bonusdifference: array[10000] of Decimal;
        Style: Text;
        TempCustItems: Record "FSN Replen. Template Matrix";

    procedure Load(MatrixColumns1: array[32] of Text[1024]; var MatrixRecords1: array[32] of Record "Location"; var MatrixRecord1: Record "Location")
    begin
        COPYARRAY(MATRIX_ColumnCaption, MatrixColumns1, 1);
        COPYARRAY(MatrixRecords, MatrixRecords1, 1);
        MatrixRecord.COPY(MatrixRecord1);
    end;


    procedure SetVisible()
    begin
        Field1Visible := MATRIX_ColumnCaption[1] <> '';
        Field2Visible := MATRIX_ColumnCaption[2] <> '';
        Field3Visible := MATRIX_ColumnCaption[3] <> '';
        Field4Visible := MATRIX_ColumnCaption[4] <> '';
        Field5Visible := MATRIX_ColumnCaption[5] <> '';
        Field6Visible := MATRIX_ColumnCaption[6] <> '';
        Field7Visible := MATRIX_ColumnCaption[7] <> '';
        Field8Visible := MATRIX_ColumnCaption[8] <> '';
        Field9Visible := MATRIX_ColumnCaption[9] <> '';
        Field10Visible := MATRIX_ColumnCaption[10] <> '';
        Field11Visible := MATRIX_ColumnCaption[11] <> '';
        Field12Visible := MATRIX_ColumnCaption[12] <> '';
        Field13Visible := MATRIX_ColumnCaption[13] <> '';
        Field14Visible := MATRIX_ColumnCaption[14] <> '';
        Field15Visible := MATRIX_ColumnCaption[15] <> '';
        Field16Visible := MATRIX_ColumnCaption[16] <> '';
        Field17Visible := MATRIX_ColumnCaption[17] <> '';
        Field18Visible := MATRIX_ColumnCaption[18] <> '';
        Field19Visible := MATRIX_ColumnCaption[19] <> '';
        Field20Visible := MATRIX_ColumnCaption[20] <> '';
        Field21Visible := MATRIX_ColumnCaption[21] <> '';
        Field22Visible := MATRIX_ColumnCaption[22] <> '';
        Field23Visible := MATRIX_ColumnCaption[23] <> '';
        Field24Visible := MATRIX_ColumnCaption[24] <> '';
        Field25Visible := MATRIX_ColumnCaption[25] <> '';
        Field26Visible := MATRIX_ColumnCaption[26] <> '';
        Field27Visible := MATRIX_ColumnCaption[27] <> '';
        Field28Visible := MATRIX_ColumnCaption[28] <> '';
        Field29Visible := MATRIX_ColumnCaption[29] <> '';
        Field30Visible := MATRIX_ColumnCaption[30] <> '';
        Field31Visible := MATRIX_ColumnCaption[31] <> '';
        Field32Visible := MATRIX_ColumnCaption[32] <> '';
    end;


    procedure OnValidateTmp(ColumnID: Integer)
    var
        lTxt1: Label 'Cant be create new quantity, Replen. Line not exists';
        ReplenTemplate: Record "LSC Replen. Template";
        ReplenCalculation: Codeunit "LSC Replen. Calculation";
        IsLocationLevelAggregation: Boolean;
        ReplenishmentJournalLines: Record "LSC Replen. Journal Lines";
        NewQtyBase: Decimal;
    begin
        //JournalDetails.SETCURRENTKEY("Replenishment Template Code","Batch No.","Line No.","Detail Line No.");

        //CSMQ120216
        IF (ColumnID MOD 4 = 0) THEN BEGIN
            /* JournalDetails.RESET;
             JournalDetails.SETRANGE("Replenishment Template Code", "Replenishment Template Code");
             JournalDetails.SETRANGE("Line No.", "Line No.");
             JournalDetails.SETRANGE("Item No.", "Item No.");
             JournalDetails.SETRANGE("Location Code", MatrixRecords[ColumnID - 3].Code);
             IF JournalDetails.FINDFIRST THEN BEGIN
                 bonusdifference["Line No." / 10000] += JournalDetails.Bonificado - MATRIX_CellData[ColumnID];
                 IF bonusdifference["Line No." / 10000] < 0 THEN BEGIN
                     bonusdifference["Line No." / 10000] -= JournalDetails.Bonificado - MATRIX_CellData[ColumnID];
                     ERROR('El valor sobrepasa el total de articulos bonificados para la linea %1, articulo %2', "Line No.", "Barcode No.");
                 END
                 ELSE
                     IF bonusdifference["Line No." / 10000] > 0 THEN BEGIN
                         Style := 'StandardAccent';
                         JournalDetails.VALIDATE(Bonificado, MATRIX_CellData[ColumnID]);
                         JournalDetails.MODIFY(TRUE);
                     END
                     ELSE BEGIN
                         Style := 'None';
                         JournalDetails.VALIDATE(Bonificado, MATRIX_CellData[ColumnID]);
                         JournalDetails.MODIFY(TRUE);
                     END;
             END
             ELSE
                 MATRIX_CellData[ColumnID] := 0;*/
            Message(lTxt1);
            MATRIX_CellData[ColumnID] := 0;
        END
        ELSE BEGIN
            JournalDetails.RESET;
            JournalDetails.SETRANGE("Replenishment Template Code", "Replenishment Template Code");
            JournalDetails.SETRANGE("Line No.", "Line No.");
            JournalDetails.SETRANGE("Item No.", "Item No.");
            JournalDetails.SETRANGE("Location Code", MatrixRecords[ColumnID].Code);
            IF JournalDetails.FINDFIRST THEN BEGIN
                //JournalDetails.VALIDATE(Quantity, MATRIX_CellData[ColumnID]);

                //NewQtyBase := MATRIX_CellData[ColumnID];
                //if Item_l.Get(Rec."Item No.") then
                //if UOM.Get(Item_l."No.", Item_l."Purch. Unit of Measure") then

                NewQtyBase := MATRIX_CellData[ColumnID] * Rec."Qty. per Unit of Measure";

                JournalDetails.Validate(JournalDetails.Quantity, NewQtyBase);
                JournalDetails.MODIFY(TRUE);
                CurrPage.Update(true);
                ReplenTemplate.Get("Replenishment Template Code");
                ReplenishmentJournalLines.Get("Replenishment Template Code", "Batch No.", "Line No.");
                IsLocationLevelAggregation := (ReplenTemplate."Purchase Order Type" = ReplenTemplate."Purchase Order Type"::"Purchase Orders for Receiving Locations") and (ReplenTemplate."Select Lowest Cost By" = ReplenTemplate."Select Lowest Cost By"::"Item and Location");
                ReplenCalculation.UpdateDirectCostForPurchReplenJnlManualUpdate("Vendor No.", JournalDetails, ReplenishmentJournalLines."Unit of Measure Code", false, IsLocationLevelAggregation, false);
                CurrPage.Update(false);

            END
            else begin
                MATRIX_CellData[ColumnID] := 0;
            end;
        END;
    end;

    local procedure MATRIX_OnAfterGetRecordQty(ColumnID: Integer)
    var
        ItemRJD: Record "LSC Replen. Jrnl. Details";
    begin
        ItemRJD.RESET;
        ItemRJD.SETRANGE("Replenishment Template Code", Rec."Replenishment Template Code");
        ItemRJD.SETRANGE("Item No.", Rec."Item No.");
        ItemRJD.SetRange("Line No.", Rec."Line No.");//WVILLALTA
        ItemRJD.SETRANGE("Location Code", MatrixRecords[ColumnID].Code);
        IF ItemRJD.FINDFIRST THEN
            //MATRIX_CellData[ColumnID] := ItemRJD.Quantity
            MATRIX_CellData[ColumnID] := ItemRJD.Quantity / Rec."Qty. per Unit of Measure"//WVILLALTA
        ELSE
            MATRIX_CellData[ColumnID] := 0;
        SetVisible;
    end;

    local procedure MATRIX_OnAfterGetRecordAvg(ColumnID: Integer)
    var
        ItemRJD: Record "LSC Replen. Jrnl. Details";
    begin
        ItemRJD.RESET;
        ItemRJD.SETRANGE("Replenishment Template Code", Rec."Replenishment Template Code");
        ItemRJD.SETRANGE("Item No.", Rec."Item No.");
        ItemRJD.SetRange("Line No.", Rec."Line No.");//WVILLALTA
        ItemRJD.SETRANGE("Location Code", MatrixRecords[ColumnID - 1].Code);
        IF ItemRJD.FINDFIRST THEN
            //MATRIX_CellData[ColumnID] := ItemRJD."Average Daily Sales"
            MATRIX_CellData[ColumnID] := ItemRJD."Average Daily Sales" / Rec."Qty. per Unit of Measure"//WVILLALTA
        ELSE
            MATRIX_CellData[ColumnID] := 0;
        SetVisible;
    end;

    local procedure MATRIX_OnAfterGetRecordInv(ColumnID: Integer)
    var
        ItemRJD: Record "LSC Replen. Jrnl. Details";
    begin
        ItemRJD.RESET;
        ItemRJD.SETRANGE("Replenishment Template Code", Rec."Replenishment Template Code");
        ItemRJD.SETRANGE("Item No.", Rec."Item No.");
        ItemRJD.SetRange("Line No.", Rec."Line No.");//WVILLALTA
        ItemRJD.SETRANGE("Location Code", MatrixRecords[ColumnID - 2].Code);
        IF ItemRJD.FINDFIRST THEN
            //MATRIX_CellData[ColumnID] := ItemRJD."Effective Inventory"
            MATRIX_CellData[ColumnID] := ItemRJD."Effective Inventory" / Rec."Qty. per Unit of Measure"//WVILLALTA
        ELSE
            MATRIX_CellData[ColumnID] := 0;
        SetVisible;
    end;

    local procedure MATRIX_OnAfterGetRecordBon(ColumnID: Integer)
    var
        ItemRJD: Record "LSC Replen. Jrnl. Details";
    begin
        /*ItemRJD.RESET;
        ItemRJD.SETRANGE("Replenishment Template Code", Rec."Replenishment Template Code");
        ItemRJD.SETRANGE("Item No.", Rec."Item No.");
        ItemRJD.SETRANGE("Location Code", MatrixRecords[ColumnID - 3].Code);
        IF ItemRJD.FINDFIRST THEN
            //MATRIX_CellData[ColumnID] := ItemRJD.Bonificado 
            MATRIX_CellData[ColumnID] := 0
        ELSE
            MATRIX_CellData[ColumnID] := 0;
        *///Not used in BC
        MATRIX_CellData[ColumnID] := 0;
        SetVisible;
    end;

    trigger OnClosePage()
    begin
        OnOpenDetailForm;
    end;

    procedure OnOpenDetailForm()
    var
        NewQuantity: Decimal;
        NewSSQ: Decimal;
        NewEffQty: Decimal;
        VendorNo: Code[20];
        ReplenishmentJournalLines: Record "LSC Replen. Journal Lines";
        ReplenishmentJrnlDetails: record "LSC Replen. Jrnl. Details";
        ReplenishmentSetup: Record "LSC Replen. Setup";
        NotFullMultiple: Label 'The changed %1 is not in full Multiple.';
    begin
        //OpenDetailForm
        ReplenishmentJournalLines.Reset();
        ReplenishmentJournalLines.SetRange(ReplenishmentJournalLines."Replenishment Template Code", Rec."Replenishment Template Code");
        ReplenishmentJournalLines.SetRange(ReplenishmentJournalLines."Batch No.", Rec."Batch No.");
        if ReplenishmentJournalLines.find('-') then
            repeat
                NewQuantity := 0;
                NewSSQ := 0;
                NewEffQty := 0;
                VendorNo := '';
                ReplenishmentJrnlDetails.Reset();
                ReplenishmentJrnlDetails.SetRange(ReplenishmentJrnlDetails."Replenishment Template Code", ReplenishmentJournalLines."Replenishment Template Code");
                ReplenishmentJrnlDetails.SetRange(ReplenishmentJrnlDetails."Batch No.", ReplenishmentJournalLines."Batch No.");
                ReplenishmentJrnlDetails.SetRange(ReplenishmentJrnlDetails."Line No.", ReplenishmentJournalLines."Line No.");
                if ReplenishmentJrnlDetails.FindSet then begin
                    VendorNo := ReplenishmentJrnlDetails."Vendor No.";
                    repeat

                        NewQuantity := NewQuantity + ReplenishmentJrnlDetails.Quantity;
                        NewSSQ := NewSSQ + ReplenishmentJrnlDetails."System Suggested Quantity";
                        NewEffQty := NewEffQty + ReplenishmentJrnlDetails."Effective Inventory";
                        if VendorNo <> ReplenishmentJrnlDetails."Vendor No." then
                            VendorNo := '';
                    until ReplenishmentJrnlDetails.Next = 0;
                end;
                ReplenishmentJournalLines.Quantity := NewQuantity;
                ReplenishmentJournalLines."System Suggested Quantity" := NewSSQ;
                ReplenishmentJournalLines."Store Effective Inventory" := NewEffQty;
                ReplenishmentJournalLines."Vendor No." := VendorNo;
                ReplenishmentJournalLines.Modify;
                ReplenishmentSetup.Get;
                if ReplenishmentSetup."Purch. Repl. Jnl. Qty. Warning" = ReplenishmentSetup."Purch. Repl. Jnl. Qty. Warning"::"Warn if Not Full Multiple" then
                    if not ReplenishmentJournalLines.QuantityIsFullMultiple then
                        Message(NotFullMultiple, ReplenishmentJournalLines.FieldCaption(Quantity));
                CurrPage.Update(false);
            until ReplenishmentJournalLines.Next() = 0;
    end;
}


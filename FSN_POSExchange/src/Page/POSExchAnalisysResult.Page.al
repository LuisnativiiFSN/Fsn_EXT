page 50030 "FSN POS Exch. Analisys Result"
{

    Caption = 'FSN POS Exch. Analisys Result';
    InsertAllowed = false;
    PageType = List;
    SourceTable = "FSN Global Table Temporary";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code20_1; Code20_1)
                {
                    Caption = 'Receipt';
                }
                field(Int_1; Int_1)
                {
                    Caption = 'Transaction';
                }
                field(Int_3; Int_3)
                {
                    Caption = 'Line';
                }
                field(Code10_1; Code10_1)
                {
                    Caption = 'Store';
                }
                field(Code10_2; Code10_2)
                {
                    Caption = 'Terminal';
                }
                field(Code20_2; Code20_2)
                {
                    Caption = 'Item';
                }
                field(Code10_3; Code10_3)
                {
                    Caption = 'UnitOfMeasure';
                }
                field(Int_2; Int_2)
                {
                    Caption = 'Quantity';
                }
                field(GetItemDescriptionByUM; GetItemDescriptionByUM(Code20_2, Code10_3))
                {
                    Caption = 'Item Description';
                }
                field(Date_1; Date_1)
                {
                    Caption = 'Transaction Date';
                }
                field(Text_1; Text_1)
                {
                    Caption = 'Status';
                }
                field("Message Process"; "Message Process")
                {
                    Caption = 'Message Process';
                }
                field(Bool_1; Bool_1)
                {
                    Caption = 'Error';
                }
                field(Bool_2; Bool_2)
                {
                    Caption = 'IsPartial';
                }
                field(Counter1; Counter1)
                {
                    Caption = 'Track';
                }
            }
        }
    }

    actions
    {
    }

    trigger OnOpenPage()
    var
        i: Integer;
        c: Integer;
        d: Date;
    begin
        RecTemp.RESET;

        /*
        IF RecTemp.FINDSET THEN REPEAT
          Rec.INIT();
          Rec := RecTemp;
          Rec.INSERT();
        
        UNTIL RecTemp.NEXT = 0;
        */
        FOR i := 1 TO gCounter DO BEGIN
            Rec.INIT();
            Rec.Code20_1 := gTableArray[i] [1];
            IF EVALUATE(c, gTableArray[i] [2]) THEN
                Rec.Int_1 := c;
            IF EVALUATE(c, gTableArray[i] [3]) THEN
                Rec.Int_3 := c;
            Rec.Code10_1 := gTableArray[i] [4];
            Rec.Code10_2 := gTableArray[i] [5];
            Rec.Code20_2 := gTableArray[i] [6];
            Rec.Code10_3 := gTableArray[i] [7];
            IF EVALUATE(c, gTableArray[i] [8]) THEN
                Rec.Int_2 := c;
            IF EVALUATE(d, gTableArray[i] [9]) THEN
                Rec.Date_1 := d;
            Rec."Message Process" := gTableArray[i] [10];
            Rec.Bool_1 := (gTableArray[i] [11] = '1');
            Rec.Bool_2 := FALSE;
            IF EVALUATE(c, gTableArray[i] [13]) THEN
                Rec.Counter1 := c;
            Text_1 := gTableArray[i] [14];
            /*
                gTableArray[i][1] := POSExchTrans."Receipt No.";
                gTableArray[i][2] := FORMAT(POSExchTrans."Transaction No.");
                gTableArray[i][3] := FORMAT(POSExchTrans."Line No.");
                gTableArray[i][4] := POSExchTrans."Store No.";
                gTableArray[i][5] := POSExchTrans."POS Terminal No.";
                gTableArray[i][6] := POSExchTrans."Item No.";
                gTableArray[i][7] := POSExchTrans."Unit of Measure";
                gTableArray[i][8] := FORMAT(POSExchTrans.Quantity);
                gTableArray[i][9] := FORMAT(POSExchTrans."Transaction Date");
                gTableArray[i][10] := COPYSTR(TextStatus,1,75);
                IF (TextStatus <> '') THEN
                  gTableArray[i][11] := '1'
                ELSE
                  gTableArray[i][11] := '0';
                gTableArray[i][12] := '0';
                gTableArray[i][13] := FORMAT(Rec.Counter1);
             */
            Rec.INSERT();
        END;

    end;

    var
        RecTemp: Record "FSN Global Table Temporary";
        gCounter: Integer;
        gTableArray: array[1000, 14] of Text[75];

    procedure InsertTrack(POSExchTransTable: Record "FSN POS Exchange Transaction"; Apply: Boolean; Track: Integer; Partial: Boolean; _Message: Text[150])
    begin
        RecTemp.INIT();
        RecTemp.Code20_1 := POSExchTransTable."Receipt No.";
        RecTemp.Int_1 := POSExchTransTable."Transaction No.";
        RecTemp.Int_3 := POSExchTransTable."Line No.";
        RecTemp.Code10_1 := POSExchTransTable."Store No.";
        RecTemp.Code10_2 := POSExchTransTable."POS Terminal No.";
        RecTemp.Code20_2 := POSExchTransTable."Item No.";
        RecTemp.Code10_3 := POSExchTransTable."Unit of Measure";
        RecTemp.Int_2 := POSExchTransTable.Quantity;
        RecTemp.Date_1 := POSExchTransTable."Transaction Date";
        RecTemp."Message Process" := _Message;
        RecTemp.Bool_1 := Apply;
        RecTemp.Bool_2 := Partial;
        RecTemp.Counter1 := Track;
        RecTemp.INIT();
    end;

    procedure DeleteTracks()
    begin
        CLEAR(gTableArray);
    end;

    procedure InitArray(TableArray: array[1000, 14] of Text[75]; Counter_: Integer)
    var
        j: Integer;
        P: Integer;
    begin
        gCounter := Counter_;
        FOR j := 1 TO Counter_ DO
            FOR P := 1 TO 14 DO
                gTableArray[j] [P] := TableArray[j] [P];
    end;
}


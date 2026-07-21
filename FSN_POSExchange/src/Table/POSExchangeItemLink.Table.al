table 50069 "FSN POS Exchange Item Link"
{

    Caption = 'FSN POS Exchange Item Link';

    fields
    {
        field(10; "POS Exchange No."; Code[20])
        {
            Caption = 'POS Exchange No.';
            TableRelation = "FSN POS Exchange Setup"."No.";
            ValidateTableRelation = true;
        }
        field(20; "Item No."; Code[20])
        {
            TableRelation = Item."No.";
            ValidateTableRelation = true;

            trigger OnValidate()
            begin
                "Unit of Measure" := '';
            end;
        }
        field(21; "Unit of Measure"; Code[20])
        {
            Caption = 'Unit of Measure';
            TableRelation = "Item Unit of Measure".Code WHERE("Item No." = FIELD("Item No."));
            ValidateTableRelation = true;
        }
        field(30; "Use Inventory"; Boolean)
        {
            Caption = 'Use Inventory';
        }
    }

    keys
    {
        key(Key1; "POS Exchange No.", "Item No.", "Unit of Measure")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin

        CreateAction(2);
    end;

    trigger OnInsert()
    begin
        ValidateRecord;

        IF gPOSExchangeSetup.GET("POS Exchange No.") THEN
            "Use Inventory" := gPOSExchangeSetup."Use Inventory"
        ELSE
            "Use Inventory" := TRUE;
        CreateAction(0);
    end;

    trigger OnModify()
    begin
        ValidateRecord;

        IF FORMAT(xRec) <> FORMAT(Rec) THEN
            CreateAction(1);
    end;

    trigger OnRename()
    begin
        ValidateRecord;

        IF FORMAT(xRec) <> FORMAT(Rec) THEN
            CreateAction(3);
    end;

    var
        gPOSExchangeSetup: Record "FSN POS Exchange Setup";
        gText001: Label 'Fields %1 , %2  or %3 cant be empty';

    procedure LookUpFirstExchangeItemUM(pItem: Code[20]; pUM: Code[10]; var pCodeSetupExists: Code[20]): Boolean
    var
        POSExchangeLinks_l: Record "FSN POS Exchange Item Link";
        POSExchangeSetup_l: Record "FSN POS Exchange Setup";
    begin
        //WVILLALTA04DIC19-
        pCodeSetupExists := '';

        POSExchangeLinks_l.RESET;
        POSExchangeLinks_l.SETRANGE(POSExchangeLinks_l."Item No.", pItem);
        POSExchangeLinks_l.SETRANGE(POSExchangeLinks_l."Unit of Measure", pUM);
        IF POSExchangeLinks_l.FIND('-') THEN
            REPEAT

                IF POSExchangeSetup_l.GET(POSExchangeLinks_l."POS Exchange No.") THEN
                    pCodeSetupExists := POSExchangeSetup_l."No.";

            UNTIL (POSExchangeLinks_l.NEXT = 0) OR (pCodeSetupExists <> '');

        EXIT(pCodeSetupExists <> '');
        //WVILLALTA04DIC19+
    end;

    procedure ValidateRecord()
    begin
        IF ("Item No." = '') OR ("POS Exchange No." = '') OR ("Unit of Measure" = '') THEN
            ERROR(STRSUBSTNO(gText001, FIELDCAPTION("POS Exchange No."), FIELDCAPTION("Item No."), FIELDCAPTION("Unit of Measure")));
    end;

    procedure GetExchDescription(Record_l: Record "FSN POS Exchange Item Link") Descr: Text[50]
    var
        POSExchSetup: Record "FSN POS Exchange Setup";
    begin
        IF POSExchSetup.GET(Record_l."POS Exchange No.") THEN
            EXIT(POSExchSetup.Description);

        EXIT('');
    end;

    procedure GetItemDescription(ItemNo: Code[20]) Desc_: Text[50]
    var
        Item_l: Record "Item";
    begin
        IF Item_l.GET(ItemNo) THEN
            EXIT(Item_l.Description);

        EXIT('');
    end;

    procedure CreateAction(Type: Integer)
    var
        RecRef: RecordRef;
        xRecRef: RecordRef;
        ActionsMgt: Codeunit "LSC Actions Management";
    begin
        //LS
        //CreateAction
        //Type: 0 = INSERT, 1 = MODIFY, 2 = DELETE, 3 = RENAME
        //
        RecRef.GETTABLE(Rec);
        xRecRef.GETTABLE(xRec);
        ActionsMgt.SetCalledByTableTrigger(TRUE);

        ActionsMgt.CreateActionsByRecRef(RecRef, xRecRef, Type);
        RecRef.CLOSE;
        xRecRef.CLOSE;
    end;
}


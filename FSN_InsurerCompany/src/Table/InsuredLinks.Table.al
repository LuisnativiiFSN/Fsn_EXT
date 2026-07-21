table 50052 "FSN Insured Links"
{
    //WVILLALTA 10.21             - C/AL to AL

    fields
    {
        field(10; "Company No."; Code[10])
        {
            Caption = 'Company No.';
            TableRelation = "FSN Company Insurer"."No." WHERE(Inactive = CONST(false));

            trigger OnValidate()
            var
                xEmp: Record "FSN Company Insurer";
            begin
            end;
        }
        field(20; Card; Code[20])
        {
            Caption = 'Card';

            trigger OnValidate()
            begin
                SetTitular;
            end;
        }
        field(25; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = Customer."No.";

            trigger OnValidate()
            begin
                IF Customer.GET("Customer No.") THEN
                    Name := Customer.Name;
            end;
        }
        field(30; Name; Text[50])
        {
            Caption = 'Name';

            trigger OnValidate()
            begin
                Rec.Name := UPPERCASE(Rec.Name);
            end;
        }
        field(40; Relation; Option)
        {
            Caption = 'Relation';
            OptionCaption = 'Parent,Beneficiary';
            OptionMembers = Parent,Beneficiary;

            trigger OnValidate()
            begin
                IF Relation = Relation::Beneficiary THEN
                    "Parent Card" := '';
            end;
        }
        field(50; "Parent Card"; Code[20])
        {
            Caption = 'Parent Card';
            TableRelation = "FSN Insured Links".Card WHERE("Company No." = FIELD("Company No."),
                                                        Relation = CONST(Parent));

            trigger OnValidate()
            var
                AseguradosLinks: Record "FSN Insured Links";
            begin
                SetTitular;
                IF "Parent Card" <> '' THEN BEGIN
                    AseguradosLinks.GET("Company No.", "Parent Card");

                    IF Relation = Relation::Parent THEN
                        "Parent Card" := ''
                    ELSE
                        IF (AseguradosLinks.Relation <> AseguradosLinks.Relation::Parent) THEN
                            ERROR(STRSUBSTNO(Text001, "Parent Card"));
                END ELSE
                    IF Relation <> Relation::Parent THEN
                        ERROR(STRSUBSTNO(Text002, FORMAT(Relation)));
            end;
        }
        field(60; "Date Created"; Date)
        {
            Caption = 'Date Created';
            Editable = false;
        }
        field(70; "Created by User"; Code[50])
        {
            Caption = 'Created by User';
            Editable = false;
        }
        field(100; Email; Text[50])
        {
            Caption = 'Email';
        }
        field(110; Inactive; Boolean)
        {
            Caption = 'Inactive';
        }

    }

    keys
    {
        key(Key1; "Company No.", Card)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Card, "Company No.", Name, Relation, Inactive)
        {
        }
    }

    trigger OnDelete()
    begin
        CreateAction(2);
    end;

    trigger OnInsert()
    begin
        SetTitular;
        "Date Created" := TODAY;
        "Created by User" := USERID;

        CreateAction(0);
    end;

    trigger OnModify()
    begin
        SetTitular;
        CreateAction(1);
    end;

    trigger OnRename()
    begin
        SetTitular;
        CreateAction(3);
    end;

    var
        Customer: Record Customer;
        Text001: Label '%1 no es asegurado Titular';
        Text002: Label 'In insured type %1, parent code cant be empty';
        Text003: Label 'Fields %1 or %2 cant be empty';

    procedure CreateAction(Type: Integer)
    var
        RecRef: RecordRef;
        xRecRef: RecordRef;
        ActionsMgt: Codeunit "LSC Actions Management";
    begin
        //LS
        //Type: 0 = INSERT, 1 = MODIFY, 2 = DELETE, 3 = RENAME
        //

        RecRef.GETTABLE(Rec);
        xRecRef.GETTABLE(xRec);
        ActionsMgt.SetCalledByTableTrigger(false);
        ActionsMgt.CreateActionsByRecRef(RecRef, xRecRef, Type);
        RecRef.CLOSE;
        xRecRef.CLOSE;
    end;

    procedure SetTitular()
    begin
        IF ("Company No." = '') OR (Card = '') THEN
            ERROR(STRSUBSTNO(Text003, FIELDCAPTION("Company No."), FIELDCAPTION(Card)));

        IF (Relation = Relation::Parent) AND (Card <> '') THEN
            "Parent Card" := Card;
    end;
}


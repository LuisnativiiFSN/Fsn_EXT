table 50055 "FSN Allow/Deny Item Customer"
{
    //WVILLALTA 10.21             - C/AL to AL
    Caption = 'Item Allow/Deny';

    fields
    {
        field(10; "Line Type"; Option)
        {
            Caption = 'Line Type';
            OptionCaption = 'Company,GroupCompany,Customer';
            OptionMembers = Company,GroupCompany,Customer;

            trigger OnValidate()
            begin
                IF "Line Type" = "Line Type"::Customer THEN
                    ERROR(Text001);

                "Entity No." := '';
            end;
        }
        field(20; "Entity No."; Code[10])
        {
            Caption = 'Entity No.';
            TableRelation = IF ("Line Type" = CONST(Company)) "FSN Company Insurer"."No."
            ELSE
            IF ("Line Type" = CONST(GroupCompany)) "FSN Company Group"."No."
            ELSE
            IF ("Line Type" = CONST(Customer)) Customer."No.";
        }
        field(30; "Allow/Deny"; Option)
        {
            Caption = 'Allow/Deny';
            OptionCaption = 'Allow,Deny(Exception)';
            OptionMembers = Allow,"Deny(Exception)";

            trigger OnValidate()
            var
                xItem: Record Item;
            begin
            end;
        }
        field(40; "Item Type"; Option)
        {
            Caption = 'Item Type';
            OptionCaption = 'All,Item,SpecialGroup,Division';
            OptionMembers = All,Item,SpecialGroup,Division;

            trigger OnValidate()
            begin
                "No." := '';
            end;
        }
        field(50; "No."; Code[20])
        {
            TableRelation = IF ("Item Type" = CONST(Item)) Item."No."
            ELSE
            IF ("Item Type" = CONST(SpecialGroup)) "LSC Item Special Groups".Code
            ELSE
            IF ("Item Type" = CONST(Division)) "LSC Division".Code;

            trigger OnValidate()
            begin
                Description := '';
                CASE "Item Type" OF
                    "Item Type"::Item:
                        IF Item.GET("No.") THEN
                            Description := Item.Description;
                    "Item Type"::Division:
                        IF Division.GET("No.") THEN
                            Description := Division.Description;
                    "Item Type"::SpecialGroup:
                        IF SpecialGroup.GET("No.") THEN
                            Description := SpecialGroup.Description;
                END;
            end;
        }
        field(60; Description; Text[50])
        {
            Caption = 'Description';
        }
        field(70; Comment; Text[50])
        {
            Caption = 'Comment';
        }
    }

    keys
    {
        key(Key1; "Line Type", "Entity No.", "Item Type", "No.")
        {
            Clustered = true;
        }
        key(Key2; "Item Type", "No.")
        {
        }
        key(Key3; "Entity No.", "Allow/Deny")
        {
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
        CreateAction(0);
    end;

    trigger OnModify()
    begin
        CreateAction(1);
    end;

    trigger OnRename()
    begin
        CreateAction(3);
    end;

    var
        Item: Record Item;
        Division: Record "LSC Division";
        SpecialGroup: Record "LSC Item Special Groups";
        Text001: Label 'Type customer not used';
        Text002: Label 'Dont have permission for item %1 .%2';

    [Scope('OnPrem')]
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

    [Scope('OnPrem')]
    procedure IsExcludeItemForCustomer(pCustomer: Code[20]; pCompany: Code[20]; pItem: Code[20]; pOrigin: Integer; var TextException: Text): Boolean
    var
        lCompany: Record "FSN Company Insurer";
        lCompanyGroup: Record "FSN Company Group";
        lItem: Record Item;
        lCustomer: Record Customer;
        AllowDenyTable: Record "FSN Allow/Deny Item Customer";
        AllowDenyTableTemp: Record "FSN Allow/Deny Item Customer" temporary;
        LevelEntityPermission: Integer;
        LevelEntityDeny: Integer;
        LevelPermission: Integer;
        LevelDeny: Integer;
        DenyExists: Boolean;
        PermissionExists: Boolean;
    begin
        // 0 : Remission, 1 : POS (Not used)
        DenyExists := FALSE;
        PermissionExists := FALSE;
        AllowDenyTableTemp.RESET;
        AllowDenyTableTemp.DELETEALL;
        CLEAR(AllowDenyTableTemp);

        IF pOrigin = 0 THEN BEGIN
            IF NOT lCompany.GET(pCompany) THEN EXIT(FALSE);
            IF NOT lCustomer.GET(lCompany."Customer No.") THEN EXIT(FALSE);
            IF NOT lCustomer."FSN Item Restricted" THEN EXIT(FALSE);//tExt
            IF NOT lItem.GET(pItem) THEN EXIT(FALSE);
            FillAllowDenyTableTmp(lItem, AllowDenyTableTemp);

            IF NOT AllowDenyTableTemp.FIND('-') THEN BEGIN
                TextException := STRSUBSTNO(Text002, pItem, '');
                EXIT(TRUE);
            END;
            REPEAT
                IF NOT (((AllowDenyTableTemp."Line Type" = AllowDenyTableTemp."Line Type"::Company) AND (AllowDenyTableTemp."Entity No." = pCompany)) OR
                  ((AllowDenyTableTemp."Line Type" = AllowDenyTableTemp."Line Type"::GroupCompany) AND (AllowDenyTableTemp."Entity No." = lCompany."Company Group"))) THEN
                    AllowDenyTableTemp.DELETE;
            UNTIL AllowDenyTableTemp.NEXT = 0;

            AllowDenyTableTemp.SETCURRENTKEY("Entity No.", "Allow/Deny");
            AllowDenyTableTemp.SETRANGE(AllowDenyTableTemp."Allow/Deny", AllowDenyTableTemp."Allow/Deny"::Allow);
            IF AllowDenyTableTemp.FINDFIRST THEN BEGIN
                LevelEntityPermission := AllowDenyTableTemp."Line Type";
                LevelPermission := AllowDenyTableTemp."Allow/Deny";
                PermissionExists := TRUE;
            END;
            AllowDenyTableTemp.SETRANGE(AllowDenyTableTemp."Allow/Deny", AllowDenyTableTemp."Allow/Deny"::"Deny(Exception)");
            IF AllowDenyTableTemp.FINDFIRST THEN BEGIN
                TextException := AllowDenyTableTemp.Comment;
                LevelEntityDeny := AllowDenyTableTemp."Line Type";
                LevelDeny := AllowDenyTableTemp."Allow/Deny";
                DenyExists := TRUE;
            END;
            IF PermissionExists THEN BEGIN
                IF NOT DenyExists THEN EXIT(FALSE);

                IF LevelEntityPermission < LevelEntityDeny THEN
                    EXIT(FALSE)
                ELSE BEGIN
                    IF LevelEntityPermission = LevelEntityDeny THEN BEGIN
                        IF LevelDeny >= LevelPermission THEN BEGIN
                            TextException := STRSUBSTNO(Text002, pItem, TextException);
                            EXIT(TRUE);
                        END;
                    END ELSE BEGIN
                        TextException := STRSUBSTNO(Text002, pItem, TextException);
                        EXIT(TRUE);
                    END;
                END;
            END ELSE BEGIN
                TextException := STRSUBSTNO(Text002, pItem, TextException);
                EXIT(TRUE);
            END;
        END;
        EXIT(FALSE);
    end;

    local procedure FillAllowDenyTableTmp(pItem: Record Item; var pAllowDenyTableTemp: Record "FSN Allow/Deny Item Customer" temporary)
    var
        AllowDenyTable: Record "FSN Allow/Deny Item Customer";
        lItemSpecialLinks: Record "LSC Item/Special Group Link";
    begin
        AllowDenyTable.RESET;
        AllowDenyTable.SETCURRENTKEY("Item Type", "No.");
        AllowDenyTable.SETRANGE(AllowDenyTable."Item Type", AllowDenyTable."Item Type"::Item);
        AllowDenyTable.SETRANGE(AllowDenyTable."No.", pItem."No.");
        IF AllowDenyTable.FINDFIRST THEN
            REPEAT
                IF NOT pAllowDenyTableTemp.GET(AllowDenyTable."Line Type", AllowDenyTable."Entity No.", AllowDenyTable."Item Type", AllowDenyTable."No.") THEN BEGIN
                    pAllowDenyTableTemp.INIT();
                    pAllowDenyTableTemp := AllowDenyTable;
                    pAllowDenyTableTemp.INSERT;
                END;
            UNTIL AllowDenyTable.NEXT = 0;

        AllowDenyTable.SETRANGE(AllowDenyTable."Item Type", AllowDenyTable."Item Type"::Division);
        AllowDenyTable.SETRANGE(AllowDenyTable."No.", pItem."LSC Division Code");
        IF AllowDenyTable.FINDFIRST THEN
            REPEAT
                IF NOT pAllowDenyTableTemp.GET(AllowDenyTable."Line Type", AllowDenyTable."Entity No.", AllowDenyTable."Item Type", AllowDenyTable."No.") THEN BEGIN
                    pAllowDenyTableTemp.INIT();
                    pAllowDenyTableTemp := AllowDenyTable;
                    pAllowDenyTableTemp.INSERT;
                END;
            UNTIL AllowDenyTable.NEXT = 0;

        AllowDenyTable.SETRANGE(AllowDenyTable."Item Type", AllowDenyTable."Item Type"::SpecialGroup);

        lItemSpecialLinks.RESET;
        lItemSpecialLinks.SETRANGE(lItemSpecialLinks."Item No.", Item."No.");
        IF lItemSpecialLinks.FINDFIRST THEN
            REPEAT
                AllowDenyTable.SETRANGE(AllowDenyTable."No.", lItemSpecialLinks."Special Group Code");
                IF AllowDenyTable.FINDFIRST THEN
                    REPEAT
                        IF NOT pAllowDenyTableTemp.GET(AllowDenyTable."Line Type", AllowDenyTable."Entity No.", AllowDenyTable."Item Type", AllowDenyTable."No.") THEN BEGIN
                            pAllowDenyTableTemp.INIT();
                            pAllowDenyTableTemp := AllowDenyTable;
                            pAllowDenyTableTemp.INSERT;
                        END;
                    UNTIL AllowDenyTable.NEXT = 0;
            UNTIL lItemSpecialLinks.NEXT = 0;

        AllowDenyTable.SETRANGE(AllowDenyTable."No.");
        AllowDenyTable.SETRANGE(AllowDenyTable."Item Type", AllowDenyTable."Item Type"::All);
        IF AllowDenyTable.FINDFIRST THEN
            REPEAT
                IF NOT pAllowDenyTableTemp.GET(AllowDenyTable."Line Type", AllowDenyTable."Entity No.", AllowDenyTable."Item Type", AllowDenyTable."No.") THEN BEGIN
                    pAllowDenyTableTemp.INIT();
                    pAllowDenyTableTemp := AllowDenyTable;
                    pAllowDenyTableTemp.INSERT;
                END;
            UNTIL AllowDenyTable.NEXT = 0;
    end;
}


page 50067 "FSN Card Search Request OK"
{
    Caption = 'FSN Card Search Request OK';
    DelayedInsert = false;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "FSN POS Card Request Entry";

    layout
    {
        area(content)
        {
            group(SearchFilters)
            {
                Caption = 'Search Filters';
                field(DateFilter; DateFilter)
                {
                    Caption = 'Date Filter';

                    trigger OnValidate()
                    begin
                        SetFilters;
                    end;
                }
                field(LastDigits; LastDigits)
                {
                    Caption = 'LastDigits';

                    trigger OnValidate()
                    begin
                        SetFilters;
                    end;
                }
                field(BINFilter; BINFilter)
                {
                    Caption = 'BIN Filter';

                    trigger OnValidate()
                    begin
                        SetFilters;
                    end;
                }
                field(IsEcommerce; IsEcommerce)
                {
                    Caption = 'Is Ecommerce';

                    trigger OnValidate()
                    begin
                        SetFilters;
                    end;
                }
            }
            repeater(Group)
            {
                field(Type; IsReversTxt)
                {
                    Caption = 'Type';
                    Editable = false;
                    StyleExpr = StyleTxt;
                }
                field("Entry No."; "Entry No.")
                {
                }
                field("Type Request"; "Type Request")
                {
                }
                field(BIN; BIN)
                {
                }
                field("Date Key"; "Date Key")
                {
                }
                field("Cast Last Numbers"; "Cast Last Numbers")
                {
                }
                field("Bank Name"; "Bank Name")
                {
                }
                field("Customer No."; "Customer No.")
                {
                }
                field("Amount Input"; "Amount Input")
                {
                }
                field("Trans Authorization"; "Trans Authorization")
                {
                }
                field("Receipt No."; "Receipt No.")
                {
                }
            }
        }
    }

    actions
    {
    }

    trigger OnAfterGetRecord()
    begin
        IsReversTxt := Text001;
        StyleTxt := 'None';
        IF "Void Number" > 0 THEN BEGIN
            IsReversTxt := Text000;
            StyleTxt := 'Unfavorable';
        END;
    end;

    trigger OnInit()
    begin
        DateFilter := TODAY;
    end;

    trigger OnOpenPage()
    begin
        FILTERGROUP(2);
        SETRANGE("Response Web Ok", TRUE);
        //SETRANGE("Void Number",0);
        FILTERGROUP(0);

        SetFilters;
    end;

    var
        LastDigits: Text[5];
        DateFilter: Date;
        BINFilter: Text[6];
        IsEcommerce: Boolean;
        IsReversTxt: Text[10];
        StyleTxt: Text[20];
        Text000: Label 'Reverse';
        Text001: Label 'Buy';

    procedure SetFilters()
    begin
        IF IsEcommerce THEN
            SETRANGE("Type Request", "Type Request"::WebPage)
        ELSE
            SETRANGE("Type Request", "Type Request"::Web);
        IF DateFilter = 0D THEN BEGIN
            DateFilter := TODAY;
            SETRANGE("Date Key", TODAY);
        END ELSE
            SETRANGE("Date Key", DateFilter);
        IF LastDigits = '' THEN
            SETRANGE("Cast Last Numbers")
        ELSE
            SETRANGE("Cast Last Numbers", LastDigits);
        IF BINFilter = '' THEN
            SETRANGE(BIN)
        ELSE
            SETRANGE(BIN, BINFilter);

        CurrPage.UPDATE(FALSE);
    end;

    procedure GetLastRecord(var LastPOSCardEntry: Record "FSN POS Card Request Entry")
    begin
        LastPOSCardEntry := Rec;
    end;
}


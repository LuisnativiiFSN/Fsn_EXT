page 50059 "FSN Lookup Cards Providers" //60021 - 50100
{
    PageType = List;
    SourceTable = "FSN POS Card Providers";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Record Type"; Rec."Record Type")
                {
                }
                field("Date Key"; Rec."Date Key")
                {
                }
                field("Terminal ID"; Rec."Terminal ID")
                {
                }
                field("Auth. Code"; Rec."Auth. Code")
                {
                }
                field("Reference No."; Rec."Reference No.")
                {
                }
                field("Audit Number"; Rec."Audit Number")
                {
                }
                field("Card Mask"; Rec."Card Mask")
                {
                }
                field("Retailer ID"; Rec."Retailer ID")
                {
                }
                field("Trans. Time Text"; Rec."Trans. Time Text")
                {
                }
                field("Amount Transaction"; Rec."Amount Transaction")
                {
                }
                field("Commission Percent"; Rec."Commission Percent")
                {
                }
                field("Amount Commission"; Rec."Amount Commission")
                {
                }
                field("Provider Name"; Rec."Provider Name")
                {
                }
                field("Extra Data 1"; Rec."Extra Data 1")
                {
                }
                field("Entry No."; Rec."Entry No.")
                {
                }
                field(Status; Rec.Status)
                {
                }
                field("User No."; Rec."User No.")
                {
                }
                field("Count Records"; Rec."Count Records")
                {
                }
                field("Is Reverse"; Rec."Is Reverse")
                {
                }
                field("Amount In Payments"; Rec."Amount In Payments")
                {
                }
                field(Close; Rec.Close)
                {
                }
                field("Parent Entry No."; Rec."Parent Entry No.")
                {
                }
                field("Parent Auth. Code"; Rec."Parent Auth. Code")
                {
                }
            }
        }
    }

    actions
    {
    }

    trigger OnInit()
    begin
        LookUpOnlySelect := FALSE;
    end;

    trigger OnOpenPage()
    begin
        IF LookUpOnlySelect THEN
            SETRANGE(Close, FALSE);
    end;

    var
        LookUpOnlySelect: Boolean;


    procedure LookUPOnly()
    begin
        LookUpOnlySelect := TRUE;
    end;


    procedure GetLastRec(var pVoucherSelect: Record "FSN POS Card Providers")
    begin
        pVoucherSelect := Rec;
    end;
}


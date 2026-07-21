/*page 50108 "FSN Delivery Trip Admin"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Delivery Trip";

    layout
    {
        area(Content)
        {
            group("Delivery trip")
            {
                field("Order No."; "Order No.") { ApplicationArea = All; }
                field("Create Time"; "Create Time") { ApplicationArea = All; }
                field("Contact No."; "Contact No.") { ApplicationArea = All; }
                field("Taker Order"; "Taker Order") { ApplicationArea = All; }
                field("Order Amount"; "Order Amount") { ApplicationArea = All; }
                field(Comment; Comment) { ApplicationArea = All; }
                field("Order Address"; "Order Address") { ApplicationArea = All; }
                field(Latitude; Latitude) { ApplicationArea = All; }
                field(Longitude; Longitude) { ApplicationArea = All; }
                field("Payment Name"; "Payment Name") { ApplicationArea = All; }
                field("Address Type"; "Address Type") { ApplicationArea = All; }
                field(IsNew; IsNew) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action("Resend DAF")
            {
                ApplicationArea = All;
                Caption = 'Resend to DAF';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    daf: Codeunit "FSN DAF Integration";
                begin
                    daf.SendOrderDAF(Rec, IsNew);
                end;
            }
        }
    }
    trigger OnAfterGetRecord()
    begin
        IsNew := true;
    end;

    var
        IsNew: Boolean;
}
*/
pageextension 50089 "DAF send Test" extends "LSC Tender Type Setup List"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addafter("BIN List")
        {
            action("Resend DAF")
            {
                ApplicationArea = All;
                Caption = 'Resend to DAF';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    daf: Codeunit "FSN DAF Integration";
                    dafTrip: Record "FSN Delivery Trip";
                begin
                    Rec.reset;
                    if Rec.Find('-') then
                        repeat
                            dafTrip.reset;
                            dafTrip.SetRange("Order No.", Rec.Description);
                            if dafTrip.Find('-') then
                                daf.SendOrderDAF(dafTrip, Rec."FSN Used By Specific BIN");
                        until Rec.Next() = 0;
                end;
            }
        }
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}
pageextension 50065 "FSN DeliveryStreetsExt" extends "LSC Delivery Streets"
{
    PromotedActionCategories = 'New,Process,Other Reports,,Process Street,Links';
    layout
    {
        addafter("Street Name")
        {
            field("FSN Street Name"; "FSN Street Name")
            {
                ApplicationArea = all;
            }
        }
        addafter("Delivery Time (Min.)")
        {
            field("FSN Latitude"; "FSN Latitude")
            {
                ApplicationArea = all;
            }
            field("FSN Longitude"; "FSN Longitude")
            {
                ApplicationArea = all;
            }
            field("FSN Alter Key"; "FSN Alter Key")
            {
                ApplicationArea = all;
                Editable = false;
            }
            field("FSN Alter Key Text"; "FSN Alter Key Text")
            {
                Editable = false;
                ApplicationArea = all;
            }
            field("FSN Distance Allow Km."; "FSN Distance Allow Km.")
            {
                ApplicationArea = all;
            }
            field("FSN Distance Order Type"; "FSN Distance Order Type")
            {
                ApplicationArea = all;
            }
            field("FSN Distance Show Km."; "FSN Distance Show Km.")
            {
                ApplicationArea = all;
            }
            field("FSN Last Valid Time"; "FSN Last Valid Time")
            {
                ApplicationArea = all;
            }
            field("FSN Stores Suggest"; "FSN Stores Suggest")
            {
                ApplicationArea = all;
            }
            field("FSN Stores Complement"; "FSN Stores Complement")
            {
                ApplicationArea = all;
            }
            field("Restriction"; Restriction)
            {
                ApplicationArea = all;
            }
        }
    }

    actions
    {
        addfirst(Processing)
        {
            group("Process Street")
            {
                Caption = 'Process Street';
                action("Recalc Store Links")
                {
                    Caption = 'Recalc Store Links';
                    Image = Route;
                    Promoted = true;
                    PromotedCategory = Category4;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        COMMIT;
                        IF NOT CONFIRM(STRSUBSTNO(Text001, "Street Name")) THEN
                            EXIT;

                        IF NOT DelStoreLink.DelStreetSetupExists(MsgError) THEN
                            ERROR(MsgError);

                        IF NOT DelStoreLink.DelStreetUpdateStoreContext(Rec, MsgError) THEN
                            ERROR(MsgError);

                        i := 1;
                        MESSAGE(STRSUBSTNO(STRSUBSTNO(Text003, FORMAT(i))));
                    end;
                }
                action("Recalc Link All Stores")
                {
                    Caption = 'Recalc Link All';
                    Image = RoutingVersions;
                    Promoted = true;
                    PromotedCategory = Category4;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        COMMIT;
                        IF NOT CONFIRM(Text002) THEN
                            EXIT;

                        i := 0;

                        IF NOT DelStoreLink.DelStreetSetupExists(MsgError) THEN
                            ERROR(MsgError);

                        DelStreet.RESET;
                        IF DelStreet.FIND('-') THEN
                            REPEAT
                                DelStoreLink.DelStreetUpdateStoreContext(DelStreet, MsgError);
                                i += 1;
                            UNTIL DelStreet.NEXT = 0;

                        MESSAGE(STRSUBSTNO(STRSUBSTNO(Text003, FORMAT(i))));
                    end;
                }
                action("Upd. Distance Matrix API")
                {
                    Caption = 'Upd. Distance Google (Matrix API)';
                    Image = CountryRegion;

                    trigger OnAction()
                    begin
                        COMMIT;
                        IF NOT CONFIRM(Text006) THEN
                            EXIT;
                        DelStoreLink.DelStreetDriverDistanceAPI(Rec);
                    end;
                }
            }
        }
        addfirst(Navigation)
        {
            action("Store Links")
            {
                Caption = 'Store Links';
                Image = PreviewChecks;
                Promoted = true;
                PromotedCategory = Category5;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    PAGELinks: Page "FSN Delivery Store Links";
                    StoreLinksTable: Record "FSN Store Link";
                begin
                    StoreLinksTable.RESET;
                    StoreLinksTable.SETCURRENTKEY("Km Between Points");
                    StoreLinksTable.SETRANGE(StoreLinksTable.Type, StoreLinksTable.Type::StreetAlterKey);
                    StoreLinksTable.SETRANGE(StoreLinksTable."Parent Code", Rec."FSN Alter Key Text");
                    IF Rec."FSN Distance Order Type" = Rec."FSN Distance Order Type"::"Distance Driver" THEN BEGIN
                        StoreLinksTable.SETCURRENTKEY(Sort, "Km Distance Driver");
                        StoreLinksTable.SETFILTER(StoreLinksTable."Km Distance Driver", '>0&<=%1', Rec."FSN Distance Allow Km.");
                    END ELSE
                        StoreLinksTable.SETFILTER(StoreLinksTable."Km Between Points", '>0&<=%1', Rec."FSN Distance Allow Km.");

                    PAGELinks.SETTABLEVIEW(StoreLinksTable);
                    PAGELinks.RUN;
                end;
            }
            action("Store Setup")
            {
                Caption = 'Store Setup';
                Image = Shipment;
                Promoted = true;
                PromotedCategory = Category5;
                PromotedIsBig = true;
                RunObject = Page "FSN Delivery Store Links";
                RunPageLink = Type = CONST(StoreSetup);
                RunPageView = SORTING("Parent Code", "Link Type", "Sort", "Km Between Points");
            }
            action("Store Group Distance")
            {
                Caption = 'Store Group Distance';
                Image = Splitlines;
                Promoted = true;
                PromotedCategory = Category5;
                PromotedIsBig = true;
                RunObject = Page "FSN Delivery Store Links";
                RunPageLink = Type = CONST(StoreGroup);
                RunPageView = SORTING("Parent Code", "Link Type", "Sort", "Km Between Points");
                Visible = false;
            }
        }
    }
    var
        DelStoreLink: Codeunit "FSN Delivery Store Link";
        DelStreet: Record "LSC Delivery Street";
        MsgError: Text;
        i: Integer;
        Text001: Label 'Recalc Store Links for street %1. Do you want continue?';
        Text002: Label 'Recalc all Stores Links for all Stores.  Do you want continue?';
        Text003: Label '%1 records procesed sucessfull';
        Text006: Label 'Recalc Real Distance for Store Link?(API).';
}



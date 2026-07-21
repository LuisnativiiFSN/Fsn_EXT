page 50020 "FSN Delivery Store Links"
{
    PageType = List;
    SourceTable = "FSN Store Link";
    ApplicationArea = all;
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Type; Type)
                {
                }
                field("Parent Code"; "Parent Code")
                {
                }
                field("Parent Code Name"; "Parent Code Name")
                {
                }
                field("Link Type"; "Link Type")
                {
                }
                field("Store No."; "Store No.")
                {
                }
                field("Store Name"; "Store Name")
                {
                }
                field("Parent Latitude"; "Parent Latitude")
                {
                }
                field("Parent Longitude"; "Parent Longitude")
                {
                }
                field(Latitude; Latitude)
                {
                }
                field(Longitude; Longitude)
                {
                }
                field(Sort; Sort)
                {
                }
                field("Distance Allow Km."; "Distance Allow Km.")
                {
                }
                field("Km Between Points"; "Km Between Points")
                {
                }
                field("Km Distance Driver"; "Km Distance Driver")
                {
                }
                field("Time Driver Min."; "Time Driver Min.")
                {
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action("Recalc Store Group")
            {
                Caption = 'Recalc Store Group';
                Image = Dimensions;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = ActionVisible;

                trigger OnAction()
                begin
                    COMMIT;
                    IF NOT CONFIRM(STRSUBSTNO(Text001, "Parent Code Name")) THEN
                        EXIT;

                    IF NOT (Type = Type::StoreSetup) THEN
                        ERROR(Text004);

                    DelFuncExt.DelStreetCreateGroupStore("Parent Code");
                    COMMIT;
                    MESSAGE(Text003);
                end;
            }
            action("Recalc All  Groups")
            {
                Caption = 'Recalc All  Groups';
                Image = DimensionSets;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = ActionVisible;

                trigger OnAction()
                begin
                    COMMIT;
                    IF NOT CONFIRM(STRSUBSTNO(Text001, "Parent Code Name")) THEN
                        EXIT;

                    StoreSetup.RESET;
                    StoreSetup.SETCURRENTKEY(Type, "Parent Code", "Link Type", "Store No.");
                    StoreSetup.SETRANGE(StoreSetup.Type, StoreSetup.Type::StoreSetup);
                    StoreSetup.SETRANGE(StoreSetup."Link Type", StoreSetup."Link Type"::DeliveryStore);
                    StoreSetup.SETFILTER(StoreSetup."Parent Code", '<>%1', '');
                    IF StoreSetup.FIND('-') THEN
                        REPEAT
                            DelFuncExt.DelStreetCreateGroupStore(StoreSetup."Parent Code");
                        UNTIL StoreSetup.NEXT = 0;

                    COMMIT;
                    MESSAGE(Text003);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin

        CASE GETFILTER(Type) OF
            FORMAT(RecOption.Type::StoreSetup):
                SetActionVisible(TRUE);
            ELSE
                SetActionVisible(FALSE);
        END;
    end;

    procedure SetActionVisible(pVisible: Boolean)
    begin
        ActionVisible := pVisible;
    end;

    var
        RecOption: Record "FSN Store Link";
        ActionVisible: Boolean;
        DelFuncExt: Codeunit "FSN Delivery Store Link";
        StoreSetup: Record "FSN Store Link";
        Text001: Label 'Recalc store group %1?';
        Text002: Label 'Recalc all store groups?';
        Text003: Label 'Done!';
        Text004: Label 'Record must be type "Store Setup"';

}


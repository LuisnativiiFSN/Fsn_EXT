page 50053 "FSN Channel Links"
{
    PageType = List;
    SourceTable = "FSN POS Setup Extend";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Store No."; "Store No.")
                {
                    Caption = 'CodeArea';
                }
                field("Line No."; "Line No.")
                {

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Types: Record "FSN POS Setup Extend";
                        Actionl: Action;
                    begin
                        Types.RESET;
                        Types.SETRANGE(Types.Type, Types.Type::CallCenter);
                        Types.SETRANGE(Types."Line Type", Types."Line Type"::Parameter);
                        Types.SETRANGE(Types."Value No.", 'CHANNELTYPE');
                        Actionl := PAGE.RUNMODAL(PAGE::"FSN Call Center Channel Type", Types);
                        IF Actionl = ACTION::LookupOK THEN BEGIN
                            "Line No." := Types."Line No.";
                            Description := Types."Data Extra 1";
                        END;
                    end;
                }
                field(Description; Description)
                {
                    Caption = 'Description';
                }
            }
        }
    }

    actions
    {
    }

    trigger OnAfterGetRecord()
    begin
        CLEAR(Description);
        POSSetupExtend.RESET;
        POSSetupExtend.SETRANGE(POSSetupExtend.Type, POSSetupExtend.Type::CallCenter);
        POSSetupExtend.SETRANGE(POSSetupExtend."Line Type", POSSetupExtend."Line Type"::Parameter);
        POSSetupExtend.SETRANGE(POSSetupExtend."Value No.", 'CHANNELTYPE');
        POSSetupExtend.SETRANGE(POSSetupExtend."Line No.", "Line No.");
        POSSetupExtend.SETRANGE(POSSetupExtend."Store No.", '');
        IF POSSetupExtend.FIND('-') THEN
            Description := POSSetupExtend."Data Extra 1";
    end;

    var
        Description: Text[50];
        POSSetupExtend: Record "FSN POS Setup Extend";
}


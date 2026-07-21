page 50015 "FSN External Purch. Line"
{
    // WVILLALTA13MAY19              - New page

    PageType = List;
    SourceTable = "FSN External Purch. Line";
    ApplicationArea = ALL;
    UsageCategory = Administration;
    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; "No.")
                {
                }
                field("Line No."; "Line No.")
                {
                }
                field("Starting Date"; "Starting Date")
                {
                }
                field("Location Code"; "Location Code")
                {
                }
                field("Vendor No."; "Vendor No.")
                {
                }
                field("Vendor Name"; "Vendor Name")
                {
                }
                field("Barcode No."; "Barcode No.")
                {
                }
                field("Item No."; "Item No.")
                {
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                }
                field(Description; Description)
                {
                }
                field("Status Purchase"; "Status Purchase")
                {
                    Editable = false;
                    StyleExpr = StyleStatusText;
                }
                field(Quantity; Quantity)
                {
                }
                field("Direct Unit Cost"; "Direct Unit Cost")
                {
                }
                field(Amount; Amount)
                {
                }
                field(TransferComplete; TransferComplete)
                {
                }
                field(Received; Received)
                {
                }
                field("Description Error"; "Description Error")
                {
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action("External Sub. Lines")
            {
                Promoted = true;
                PromotedCategory = Process;
                RunObject = page "FSN External Purc. Sub Line";
                RunPageLink = "No." = field("No.");
                Image = LinkWeb;

            }

            action("Filter returned")
            {
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Image = Filter;
                Caption = 'Filtrar Rechazados';

                trigger OnAction()

                var
                    Textselect: Label 'Filtrar Cabecera,Filtrar Detalle';
                    FilterType: Integer;
                begin
                    FilterType := 0;
                    FilterType := StrMenu(Textselect, 1);//28981

                    IF FilterType <> 0 THEN
                        SETFILTERRETURD(FilterType);
                end;
            }

            action("Check Solvend")
            {
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Image = Task;
                Caption = 'Marcar Solventado';

                trigger OnAction()

                var
                    FSNExtPurchLine: Record "FSN External Purch. Line";
                begin
                    FSNExtPurchLine.Reset();
                    FSNExtPurchLine.SetRange(FSNExtPurchLine."Status Purchase", FSNExtPurchLine."Status Purchase"::returned);
                    FSNExtPurchLine.SetRange("No.", "No.");
                    if FSNExtPurchLine.Find('-') then begin
                        repeat
                            FSNExtPurchLine."Status Purchase" := FSNExtPurchLine."Status Purchase"::Solved;
                            FSNExtPurchLine.Modify(true);
                        until FSNExtPurchLine.Next() = 0;
                    end;

                end;


            }
        }
    }
    procedure SETFILTERNO(No: Code[20])
    begin
        //FILTERGROUP(2);
        SETRANGE("No.", No);
        //FILTERGROUP(0);
    end;


    procedure SETFILTERRETURD(FILT: Integer)
    begin

        CASE FILT of
            1:
                begin
                    SETRANGE("Status Purchase", "Status Purchase"::returned);
                    SETRANGE("Line No.", -10000);
                    SETRANGE("Item No.", '');
                end;
            2:
                begin
                    SETRANGE("Status Purchase", "Status Purchase"::returned);
                    SetFilter("Line No.", '<>%1', -10000);
                    SetFilter("Item No.", '<>%1', '');
                end;
        END;
    end;

    /*trigger OnOpenPage()
    var
        myInt: Integer;
        FSNExtPurchLine: Record "FSN External Purch. Line";
    begin
        FSNExtPurchLine.Reset();
        if FSNExtPurchLine.Find('-') then begin
            repeat
                Rec := FSNExtPurchLine;
                Rec.Insert();
            until FSNExtPurchLine.Next() = 0;
        end;
    end;*/

    trigger OnAfterGetRecord()
    var
        myInt: Integer;
    begin

        case format("Status Purchase") of
            format("Status Purchase"::returned):
                StyleStatusText := Format(StyleStatus::Unfavorable);
            Format("Status Purchase"::Solved):
                StyleStatusText := Format(StyleStatus::Favorable);
            Format("Status Purchase"::None):
                StyleStatusText := Format(StyleStatus::StrongAccent);
            'Rechazado':
                StyleStatusText := Format(StyleStatus::Unfavorable);
            'Solventado':
                StyleStatusText := Format(StyleStatus::Favorable);
        end;
    end;

    var
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;
        StyleStatusText: Text;
}


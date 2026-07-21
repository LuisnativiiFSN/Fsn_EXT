tableextension 50029 "FSN Replen. Item Quantity" extends "LSC Replen. Item Quantity"
{
    fields
    {
        field(102; "VP30D"; Decimal)
        {
            Caption = 'Lost Sales (30 Days)';
            DataClassification = ToBeClassified;
        }
        //"Item Unit of Measure"
        field(103; "FSN Qty. Per Unit of Measure"; Decimal)
        {
            Caption = 'FSN Qty. Per Unit of Measure';
            DataClassification = ToBeClassified;
        }

        //LSC Replen. Item Store Rec
        field(104; "FSN Minimun Base"; Decimal)
        {
            Caption = 'FSN Minimun Base';
            DataClassification = ToBeClassified;
        }
        //LSC Replen. Item Store Rec

        field(105; "FSN Maximun Base"; Decimal)
        {
            Caption = 'FSN Maximun Base';
            DataClassification = ToBeClassified;
        }
        /*
        //LSC Replen. Item Store Rec
        field(104; "FSN Reorder Point"; Decimal)
        {
            Caption = 'FSN Reorder Point';
            DecimalPlaces = 0 : 5;
        }
        //LSC Replen. Item Store Rec
        field(105; "FSN Maximum Inventory"; Decimal)
        {
            Caption = 'FSN Maximum Inventory';
            DecimalPlaces = 0 : 5;
        }
        */
        //LSC Replen. Item Store Rec
        field(106; "FSN Transfer Multiple"; Decimal)
        {
            Caption = 'FSN Transfer Multiple';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        //LSC Replen. Item Store Rec
        field(107; "FSN Approach Multiple"; Decimal)
        {
            Caption = 'FSN Approach Multiple';
        }
        //LSC Replen. Item Store Rec
        field(108; "FSN Purchase Order Multiple"; Decimal)
        {
            Caption = 'FSN Purchase Order Multiple';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        //FSN Replen. Jrnl. Add
        field(109; "FSN Replen. Template Code Add"; Code[10])
        {
            Caption = 'FSN Replen. Template Code';
        }
        //FSN Replen. Jrnl. Add
        field(110; "FSN Quantity Add"; Decimal)
        {
            Caption = 'FSN Quantity';
        }

        //Item
        field(111; "FSN Base Unit of Measure"; Code[10])
        {
            Caption = 'FSN Base Unit of Measure';
        }
        //Item
        field(112; "FSN Purch. Unit of Measure"; Code[10])
        {
            Caption = 'FSN Purch. Unit of Measure';
        }



    }
}
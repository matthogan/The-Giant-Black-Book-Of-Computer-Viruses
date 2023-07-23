rem \tasm\bin\tasm32 /ml /m3 /zi %1,,;
\tasm\bin\tasm32 /ml /m3 %1,,;
\tasm\bin\tlink32 /Tpe /aa /c /v /Sc:4000 /Hc:4000 %1,%1,, import32.lib,%1.def

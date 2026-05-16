
#include "TextFormatInfo.h"
char TextFormatInfo::NewLine[] = {'\r', '\n', '\0'};
uint8_t TextFormatInfo::DecimalDigits = (uint8_t)2;
char TextFormatInfo::NegativeSign = {'-'};
char TextFormatInfo::DecimalSeparator = {'.'};
uint8_t TextFormatInfo::DefaultBase = (uint8_t)TextFormatInfo::baseDecimal;

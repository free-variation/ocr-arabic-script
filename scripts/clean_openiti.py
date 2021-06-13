import sys
import re
import unicodedata as ud
from functools import partial

def clean(lines):
    remove_chars = partial(re.compile('[a-zA-Z0-9#~\n\t@\|<>&+%:]').sub, '')
    remove_empty_parens = partial(re.compile('\(\s*\)').sub, '')
    remove_multiple_periods = partial(re.compile('(\. )+\.').sub, '')
    arabic = re.compile('[\u0600-\u06ff]|[\u0750-\u077f]|[\ufb50-\ufbc1]|[\ufbd3-\ufd3f]|[\ufd50-\ufd8f]|[\ufd92-\ufdc7]|[\ufe70-\ufefc]|[\uFDF0-\uFDFD]')
    
    _has_arabic = arabic.search
    _remove_non_arabic = lambda s: remove_multiple_periods(remove_empty_parens(remove_chars(s)))
    
    braces, squares = 0, 0
    
    def _clean(s):
        nonlocal braces, squares

        s1 = _remove_non_arabic(s)
        r = ''

        for c in s1:
            if c == '{':
                braces += 1
            elif c == '}':
                braces -= 1
            elif c == '[':
                squares += 1
            elif c == ']':
                squares -= 1
            elif braces == 0 and squares == 0:
                r += c
        
        # this is reputed to be fast and "pythonic"; shrug.
        return ' '.join(r.split())
    
    return (cleaned_line for cleaned_line in 
            (_clean(line) for line in lines) 
            if _has_arabic(cleaned_line))

if __name__ == '__main__':

    for filename in sys.argv[1:]:
        with open(filename, 'r') as f:
            for arabic_line in clean(f):
                # Applying canonical decomposition normalization form
                print(ud.normalize('NFD',arabic_line))

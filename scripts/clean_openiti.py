import re

def clean(lines):
    braces = 0
    squares = 0
    
    remove = re.compile('[a-zA-Z0-9#~\n\t]|(::)')
    arabic = re.compile('[\u0600-\u06ff]|[\u0750-\u077f]|[\ufb50-\ufbc1]|[\ufbd3-\ufd3f]|[\ufd50-\ufd8f]|[\ufd92-\ufdc7]|[\ufe70-\ufefc]|[\uFDF0-\uFDFD]')
    _has_arabic = arabic.search
    def _remove_non_arabic(s):
        return remove.sub('', s)
    
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
                
        return ' '.join(r.split())
    
    return [cleaned_line for cleaned_line in 
            [_clean(line) for line in lines] 
            if _has_arabic(cleaned_line)]

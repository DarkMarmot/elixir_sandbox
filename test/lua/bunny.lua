
animal_voices = {bunny="silence", cow="moo", cat="meow", dog="woof"}
talk_count = 0

function speak(animal)
    return animal_voices[animal]
end

function waste_cycles(n)
    local t = 0
    for i=1,n do
        t = t + i
    end
    return t
end

function talk(n)
    talk_count = talk_count + n
end